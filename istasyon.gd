extends Node3D

@onready var player: CharacterBody3D = $Eren
@onready var eye: Camera3D = $Eren/Bakis
@onready var hull: Node3D = $IstasyonModeli
var data: Dictionary
var locks: Dictionary = {}
var rotors: Dictionary = {}
var settings: Dictionary = {}
var taken: Dictionary = {}
var flags: Dictionary = {}
var focus_id = ""
var room_id = 3
var intro = true
var exterior = false
var orbit = 0.68
var elevation = 0.73
var radius = 48.0
var alert_time = 0.0
var exterior_cam: Camera3D
var overlay: CanvasLayer
var status: Label
var reticle: Label
var prompt: Label
var message: Label
var info: Label
var clock = 0.0
var hands_on_fuse = false
var cable_ready = false
var fault_count = 0
var relay_stage = 0
var cache_stage = 0
var bio_stage = 0
var life_ok = false
var cool_ok = false
var needles: Dictionary = {}
var hiss: AudioStreamPlayer3D
var click: AudioStreamPlayer
var screw_index = 0
var eva_active = false
var npc_nodes: Dictionary = {}
var eva_door_center: Vector3
var eva_outward: Vector3
var eva_tangent: Vector3


func v3(a) -> Vector3:
 return Vector3(float(a[0]), float(a[1]), float(a[2]))

func label_at(pos: Vector2, font_size: int, color: Color) -> Label:
 var l = Label.new()
 overlay.add_child(l)
 l.position = pos
 l.add_theme_font_size_override("font_size",font_size)
 l.add_theme_color_override("font_color",color)
 l.add_theme_color_override("font_shadow_color",Color(0,0,0,.96))
 l.add_theme_constant_override("shadow_offset_x",2)
 l.add_theme_constant_override("shadow_offset_y",2)
 return l

func _ready():
 var f = FileAccess.open("res://gorevler.json",FileAccess.READ)
 data = JSON.parse_string(f.get_as_text())
 eva_door_center = v3(data.doors.EVA.pos)
 eva_outward = Vector3(eva_door_center.x, 0.0, eva_door_center.z).normalized()
 eva_tangent = Vector3(eva_outward.z, 0.0, -eva_outward.x)

 exterior_cam = Camera3D.new()
 add_child(exterior_cam)
 exterior_cam.far=350
 overlay=CanvasLayer.new()
 add_child(overlay)
 status=label_at(Vector2(24,18),18,Color("#e0ece4"))
 reticle=label_at(Vector2.ZERO,20,Color("#e2eee1"))
 reticle.text="·"
 prompt=label_at(Vector2.ZERO,18,Color("#ffe2a6"))
 message=label_at(Vector2.ZERO,17,Color("#e7f4e6"))
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 info=label_at(Vector2(24,64),17,Color("#daebe2"))
 info.text="İSTASYON İNCELEMESİ\n\nW A S D   yürü    •    Fare   bak    •    Shift   hızlı yürü\nE   odaktaki parçayı kullan    •    F   el feneri\nTab   dış görünüş    •    1–8   bölmeye git\nEVA: Space yüksel · Ctrl alçal · R fren\nH   bu yardımı aç/kapat    •    Esc   fareyi bırak\n\nHava kilidinde başlıyorsun. Tur için geçidi izle.\nEtkileşim adı göründüğünde E tuşuna bas."
 var torch=SpotLight3D.new()
 torch.name="ElFeneri"
 eye.add_child(torch)
 torch.light_color=Color("#fff2d6")
 torch.light_energy=2.2
 torch.spot_range=9.0
 torch.spot_angle=32.0
 torch.visible=false
 for k in data.doors:
  make_door(k)
 for key in data.hits:
  var hit=data.hits[key]
  if hit.has("spin"):
   var node=hull.find_child(str(hit.spin[0]),true,false) as Node3D
   if node:
    rotors[key]={"node":node,"axis":v3(hit.spin[2]).normalized(),"basis":node.global_transform.basis}
    settings[key]=0
  if hit.has("needle"):
   var needle_node=hull.find_child(str(hit.needle[0]),true,false) as Node3D
   if needle_node:
    var pivot=v3(hit.needle[1])
    needles[key]={"node":needle_node,"pivot":pivot,"offset":needle_node.global_position-pivot,"base":needle_node.global_transform.basis,"axis":v3(hit.needle[2]).normalized()}
 hiss=AudioStreamPlayer3D.new()
 add_child(hiss)
 var pipe_sound=load("res://assetler/ses_hat.wav") as AudioStreamWAV
 pipe_sound.loop_mode=AudioStreamWAV.LOOP_FORWARD
 pipe_sound.loop_end=pipe_sound.data.size()/2
 hiss.stream=pipe_sound
 hiss.global_position=v3(data.hits.Oksijen2.pos)
 hiss.max_distance=6.2
 hiss.volume_db=-9
 hiss.play()
 click=AudioStreamPlayer.new()
 add_child(click)
 click.stream=load("res://assetler/ses_tik.wav")
 click.volume_db=-13
 for i in range(8):
  var sp=data.spawns[i]
  var ang=float(i)*PI/4.0
  var n=Vector3(-sin(ang),0,-cos(ang))
  for offset in [-2.1,2.1]:
   var lamp=OmniLight3D.new()
   add_child(lamp)
   lamp.position=v3(sp.pos)+n*2.1+Vector3(cos(ang),0,-sin(ang))*offset+Vector3.UP*2.57
   lamp.omni_range=6.0
   lamp.light_energy=.84
   lamp.light_color=Color("#d6eff3") if offset>0 else Color("#ffe6bc")
 prepare_crew()
 jump_room(3)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func make_door(key):
 var d=data.doors[key]
 var pos=v3(d.pos)
 var body=StaticBody3D.new()
 add_child(body)
 body.position=Vector3(pos.x,float(d.height)/2,pos.z)
 body.rotation.y=float(d.yaw)
 var col=CollisionShape3D.new()
 var shape=BoxShape3D.new()
 shape.size=Vector3(float(d.width),float(d.height),.13)
 col.shape=shape
 body.add_child(col)
 var leaves=[]
 for pair in d.leaves:
  var n=hull.find_child(str(pair[0]),true,false) as Node3D
  if n: leaves.append({"node":n,"pos":n.position,"offset":v3(pair[1])})
 var is_open=str(key).begins_with("Gecis")
 locks[key]={"open":is_open,"shape":col,"parts":leaves,"amount":1.0 if is_open else 0.0}
 col.disabled=is_open
 for part in leaves:
  if is_open:part.node.position=part.pos+part.offset

func jump_room(i):
 room_id=i
 player.global_position=v3(data.spawns[i].pos)
 player.rotation=Vector3(0,float(data.spawns[i].yaw),0)
 eye.rotation=Vector3.ZERO
 player.velocity=Vector3.ZERO
 set_eva(false)
 hands_on_fuse=false
 if exterior: toggle_view()
 focus_id=""

func toggle_view():
 exterior=not exterior
 if exterior:
  exterior_cam.current=true
  info.visible=false
 else:eye.current=true
 focus_id=""

func _unhandled_input(ev):
 if ev is InputEventMouseButton and ev.pressed:
  if ev.button_index==MOUSE_BUTTON_LEFT:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  if exterior:
   if ev.button_index==MOUSE_BUTTON_WHEEL_UP:radius=maxf(24.0,radius-2)
   if ev.button_index==MOUSE_BUTTON_WHEEL_DOWN:radius=minf(85.0,radius+2)
 if ev is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  if exterior:
   orbit-=ev.relative.x*.006
   elevation=clampf(elevation+ev.relative.y*.004,-1.35,1.35)
  else:
   player.rotate_y(-ev.relative.x*.0025)
   eye.rotation.x=clampf(eye.rotation.x-ev.relative.y*.0025,-1.43,1.43)
 if ev is InputEventKey and ev.pressed and not ev.echo:
  var k=ev.physical_keycode
  if k==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  if k==KEY_H:info.visible=not info.visible
  if k==KEY_TAB:toggle_view()
  if k==KEY_F:eye.get_node("ElFeneri").visible=not eye.get_node("ElFeneri").visible
  if k>=KEY_1 and k<=KEY_8:jump_room(k-KEY_1)
  if k==KEY_E and not exterior and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and focus_id!="":
   info.visible=false
   click.play()
   if focus_id.begins_with("door/"):use_door(focus_id.trim_prefix("door/"))
   else:use_target(focus_id)

func _physics_process(dt):
 if data.is_empty():return
 clock+=dt
 for key in needles:
  var d=needles[key]
  var idx=int(str(key).right(1))
  var a=[-.74,-.05,.72][idx]
  if str(key).begins_with("Oksijen") and idx==2 and not life_ok:a+=.32*sin(clock*1.6)
  if str(key).begins_with("Sogutma") and idx==1 and not cool_ok:a-=.48*(.5+.5*sin(clock*1.4))
  if (str(key).begins_with("Oksijen") and life_ok) or (str(key).begins_with("Sogutma") and cool_ok):a=-.09
  var twist=Basis(d.axis,a)
  d.node.global_transform=Transform3D(twist*d.base,d.pivot+twist*d.offset)
 if hiss:hiss.volume_db=move_toward(hiss.volume_db,-80.0 if life_ok else -9.0,dt*45.0)
 if not exterior:
  move_player(dt)
 else:
  exterior_cam.position=Vector3(cos(orbit)*cos(elevation),sin(elevation),sin(orbit)*cos(elevation))*radius+Vector3.UP
  exterior_cam.look_at(Vector3.UP,Vector3.UP)
 for key in locks:
  var d=locks[key]
  var next=move_toward(float(d.amount),1.0 if d.open else 0.0,dt*2.3)
  if next!=d.amount:
   d.amount=next
   for part in d.parts:part.node.position=part.pos+part.offset*next
   d.shape.set_deferred("disabled",next>.88)
 nearest_room()
 update_focus()
 hud(dt)

func nearest_room():
 if exterior or eva_active:return
 var best=10000.0
 for i in range(8):
  var dist=player.global_position.distance_squared_to(v3(data.spawns[i].pos))
  if dist<best:
   best=dist
   room_id=i

func candidate(p:Vector3,limit:float) -> float:
 var delta=p-eye.global_position
 var dist=delta.length()
 if dist>limit or dist<.03:return -100
 var dot=(-eye.global_transform.basis.z).dot(delta/dist)
 if dot<.952:return -100
 var query=PhysicsRayQueryParameters3D.create(eye.global_position,p)
 query.exclude=[player.get_rid()]
 var ray=get_world_3d().direct_space_state.intersect_ray(query)
 if not ray.is_empty() and ray.position.distance_to(p)>.26:return -100
 return dot*4-dist*.035

func update_focus():
 focus_id=""
 if exterior:return
 var high=-98.0
 for k in data.hits:
  if str(k).begins_with("screw") and relay_stage!=2:continue
  if k=="relay" and relay_stage==2:continue
  var d=data.hits[k]
  var s=candidate(v3(d.pos),float(d.radius))
  if s>high:
   focus_id=k
   high=s
 for k in data.doors:
  var s=candidate(v3(data.doors[k].pos),2.5)
  if s>high:
   focus_id="door/"+k
   high=s

func hud(dt):
 var sz=get_viewport().get_visible_rect().size
 reticle.visible=not exterior
 reticle.position=sz/2-Vector2(4,14)
 status.text="ARK–7  /  "+("DIŞ GÖVDE" if exterior else ("EVA · 0 g" if eva_active else str(data.spawns[room_id].room).to_upper()))+"     ·     H  yardım"
 var title=""
 if exterior:title="Fare  yörünge   ·   Tekerlek  yakınlaş   ·   Tab  güverteye dön"
 elif focus_id.begins_with("door/"):
  var k=focus_id.trim_prefix("door/")
  title="E   "+("Kapıyı kapat" if locks[k].open else "Kapıyı aç")
 elif focus_id!="":title="E   "+str(data.hits[focus_id].title)
 elif eva_active:title="WASD / fare yönü · Space yüksel · Ctrl alçal · R fren"
 prompt.text=title
 prompt.position=Vector2((sz.x-prompt.get_minimum_size().x)*.5,sz.y*.68)
 message.size=Vector2(minf(900,sz.x-48),78)
 message.position=Vector2(24,sz.y-95)
 alert_time-=dt
 message.visible=alert_time>0

func say(t):
 message.text=t
 alert_time=7.5

func use_door(k):
 if k=="EVA" and not locks[k].open and locks["EVA_Ic"].amount>0.04:
  say("Basınç çevrimi için önce hava kilidinin iç kapısını kapat.")
  return
 if k=="EVA_Ic" and not locks[k].open and locks["EVA"].amount>0.04:
  say("İç kapı için önce dış kapağı kapat.")
  return
 if k=="EVA" and not flags.get("suit",false):
  say("Dış kapı kilitli. Önce raftaki EVA donanımını kuşan.")
  return
 if k=="KargoIc" and not flags.get("power",false):
  say("Kapıda enerji yok. Sol pervazdaki sigorta kolunu ve Kargo hattını kontrol et.")
  return
 var door=locks[k]
 if door.open:
  var offset=player.global_position-v3(data.doors[k].pos)
  offset.y=0
  if offset.length()<1.03:
   say("Kapının kapanabilmesi için eşikten bir adım geri çekil.")
   return
 door.open=not door.open
 if k=="KargoIc" and door.open:
  flags["rescue"]=true
  say("Kargo erişimi açıldı. "+("Gecikmeli kurtarma: Kemal yaralı." if fault_count>0 else "Zamanında kurtarma: Kemal’e ulaşılabilir."))
 elif k=="Kamara1":say("Eren’in kamara kapısı "+("açıldı." if door.open else "kapandı."))

func turn(k):
 var v=(int(settings[k])+1)%3
 settings[k]=v
 if rotors.has(k):
  var r=rotors[k]
  var node=r.node as Node3D
  node.global_transform=Transform3D(Basis(r.axis,v*PI/2.0)*r.basis,node.global_position)
 var state=["kapalı","yarım açık","açık"]
 if k.begins_with("Oksijen"):
  # These start open; position 0 = açık, 1 = yarım, 2 = kapalı.
  life_ok=(settings.get("Oksijen2",0)==2 and settings.get("Oksijen0",0)==0)
  if life_ok:say("Sağ hat kapandı. Tıslama kesildi; kapak contasını elle sık.")
  elif k=="Oksijen0" and v==2:say("Revir beslemesi kesildi. Kaçak sürüyor; sol hattı geri aç.")
  else:say("Hat %s · %s. Tıslama sürüyor; sağ ibre yükseliyor." % [str(int(k.right(1))+1),["açık","yarım açık","kapalı"][v]])
 else:
  cool_ok=settings.get("Sogutma0",0)==0 and settings.get("Sogutma1",0)==1 and settings.get("Sogutma2",0)==0
  if cool_ok:say("Isı artışı durdu. Kalibrasyon için reaktör konsoluna geçebilirsin.")
  else:say("Soğutma %s · %s. İkinci hattaki ibre düşüyor." % [str(int(k.right(1))+1),state[v]])

func use_target(k):
 if npc_nodes.has(k):
  var npc = npc_nodes[k]
  var character = npc.node as Node3D
  var target = player.global_position
  target.y = character.global_position.y
  if character.global_position.distance_to(target) > .05:
   character.look_at(target, Vector3.UP, true)
  var dialogue_text = str(npc.dialog)
  if k == "crew_Kemal" and flags.get("rescue",false):
   dialogue_text = "Sağ ol evlat. Kargo kapısı açık. Şimdi istasyonun diğer hatlarını kontrol edelim."
  elif k == "crew_Mira" and taken.has("bio"):
   dialogue_text = "İki kayıt aynı dakikayı gösteriyor. Bu kaydı iyi sakla."
  elif k == "crew_Deniz" and flags.get("relay",false):
   dialogue_text = "Yerel hat geri geldi. Şirket bağlantısı hâlâ sessiz. Önbelleği kontrol et."
  say(str(npc.name) + " · " + dialogue_text)
  return
 if k.begins_with("screw"):
  var order=[0,2,1]
  if int(k.right(1))!=order[screw_index]:
   screw_index=0
   say("Modül hizası bozuldu. Gövde üzerindeki 1 · 3 · 2 sırasını yeniden izle.")
  else:
   screw_index+=1
   if screw_index==3:
    relay_stage=3
    flags["relay"]=true
    say("Üç vida oturdu. Yerel telsiz açık; şirket hattı kapalı.")
   else:say("Vida oturdu. Sıradaki vidaya bak.")
  return
 if k.begins_with("Oksijen") or k.begins_with("Sogutma"):
  turn(k)
  return
 match k:
  "suit":
   flags["suit"]=true
   say("EVA kıyafeti kuşanıldı. Hava kilidinin dış kapısı kullanılabilir.")
  "relay":
   if relay_stage==0:
    taken["kesik"]=true
    relay_stage=1
    say("Bir kenar düzgün kesilmiş. İnceleme kaydedildi; yedek modülü oturtmak için tekrar kullan.")
   elif relay_stage==1:
    relay_stage=2
    say("Modül oturdu. Gövdedeki sıra 1 · 3 · 2. Vidaları ayrı ayrı hedefle.")
   else:
    flags["relay"]=true
    say("Röle sabitlendi. Yerel hat açık, şirket hattı hâlâ kesik.")
  "note","letter","log","card","board","vlocker":
   taken[k]=true
   var lines={"note":"Not kaydedildi: 72s → 9.","letter":"Mektup kaydedildi: Kuzey Yıldızı. Sıfırın içindeki eğik çizgi belirgin.","log":"Viktor’un defteri: sıfırlar düz yazılmış.","card":"Kart kaydı: Viktor, 03:12, Yaşam Desteği.","board":"Tahta fotoğrafı alındı: Ø. Viktor’un raporuyla karşılaştırılabilir.","vlocker":"Viktor’un dolabı: numune şişesi ve kesici kayda geçti."}
   say(lines[k])
  "seal":
   if life_ok:
    flags["sealed"]=true
    say("Conta sıkıldı. Oksijen hattı kararlı.")
   else:say("Contaya geçmeden önce kaçak hattını tam kapat.")
  "neutral":
   flags["neutral"]=true
   say("Revir dolabından nötr yedek kartuş alındı.")
  "filter":
   if flags.get("neutral",false):
    flags["filter"]=true
    taken["dust"]=true
    say("Nötr kartuş takıldı. Ağır kartuşun ağzından toz örneği alındı.")
   else:say("İki yuvayı kontrol ettin. Raf yedeği de ağır. Nötr kartuşu revirde karşılaştır.")
  "cargo_handle":
   use_door("KargoIc")
  "fuse":
   if flags.get("power",false):
    say("Hat kararlı. Pano içindeki SYS-01 ve bypass izi kaydedildi.")
    return
   if not hands_on_fuse:
    hands_on_fuse=true
    say("Sigorta tutuluyor. Elini bırakmadan üç yuvadan Kargo hattını seç.")
   else:
    hands_on_fuse=false
    if cable_ready:
     flags["power"]=true
     taken["bypass"]=true
     say("Kargo hattı döndü. SYS-01 izi göründü; manuel kapı kolu kullanılabilir.")
    else:
     fault_count+=1
     say("Sigorta erken bırakıldı; hat yeniden kesildi.")
  "plug0","plug1","plug2":
   if not hands_on_fuse:say("Önce üstteki sigorta kolunu tut.")
   elif k=="plug1":
    cable_ready=true
    say("Soğuk Kargo hattı takıldı. Şimdi kolu bırak.")
   else:
    fault_count+=1
    cable_ready=false
    say("Bu hat kısa devrede. Etiketleri yeniden karşılaştır.")
  "cache":
   cache_stage=mini(cache_stage+1,3)
   if cache_stage==1:say("Kimlik kırıntısı seçildi: SYS-01. Aynı terminalden saat kaydını getir.")
   elif cache_stage==2:say("Saat ve kapı kaydı bir arada. Kopyayı almak için tekrar kullan.")
   else:
    taken["cache"]=true
    say("EVA kaydı ve Arkon-4 taraması kopyalandı.")
  "bio":
   if not taken.has("card"):say("İki kayıt gerekli. Önce Yaşam Desteği’ndeki kart terminalini oku.")
   else:
    taken["bio"]=true
    say("03:12 eşleşmesi: kart Yaşam Desteği’nde, biyometri revirde.")
  "court":
   if taken.has("bypass"):say("Sabotaj izi masaya sunuldu. Delil incelemesi açık; saha kayıtları: %d." % taken.size())
   else:say("Madde 9: şirket hattının kesilmesi tek başına yeterli değil. Güç panosundaki sabotaj izini araştır.")
  "cal":
   if cool_ok:
    flags["cooled"]=true
    say("Kalibrasyon tamamlandı. Çekirdek sıcaklığı kararlı.")
   else:say("Üç göstergeden düşen hattı yarım aç. Diğer ikisi kapalı kalmalı.")
  "capsule":say("Tek kişilik tahliye kapsülü. Koltuk, bağımsız itki ve servis kapağı hazır.")
  "meal":say("Altı kişilik vardiya masası. Koridor altı ayrı kamaraya uzanıyor.")
  "cabin":say("Eren’in kamara terminali ve notu aynı bakışta. Sayaç: 00:00.")

# NPCs remain in their work areas and can be inspected with the same E interaction.
func prepare_crew():
 for member in data.crew:
  var character = $Murettebat.get_node_or_null(str(member.node)) as Node3D
  if character == null:
   continue
  var key = "crew_" + str(member.node)
  npc_nodes[key] = {"node":character,"name":member.name,"dialog":member.dialog}
  data.hits[key] = {"pos":[character.position.x,character.position.y+1.32,character.position.z],"title":str(member.name)+" · konuş","radius":2.65}
  var body = StaticBody3D.new()
  body.name = "KisiCarpismasi"
  character.add_child(body)
  var shape = CapsuleShape3D.new()
  shape.radius = .21
  shape.height = 1.6
  var collider = CollisionShape3D.new()
  collider.position.y = .80
  collider.shape = shape
  body.add_child(collider)
  var tag = Label3D.new()
  tag.text = str(member.name) + "\n" + str(member.role)
  tag.position.y = 2.06
  tag.font_size = 30
  tag.outline_size = 6
  tag.pixel_size = .0026
  tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  tag.modulate = Color("#e4f2e6")
  character.add_child(tag)

func set_eva(active: bool):
 if eva_active == active:
  return
 eva_active = active
 player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if active else CharacterBody3D.MOTION_MODE_GROUNDED
 player.floor_snap_length = 0.0 if active else .22
 if not active:
  player.velocity.y = 0.0
 if active:
  say("Yer çekimsiz alan. WASD ile uç, Space/Ctrl ile yüksel/alçal, R ile fren yap.")
 else:
  say("Hava kilidine döndün. Yapay yer çekimi etkin.")

func detect_eva_crossing(previous: Vector3):
 # Test the actual movement segment against the outer hatch plane.
 if not locks["EVA"].open or float(locks["EVA"].amount) < .88:
  return
 var old_side = (previous-eva_door_center).dot(eva_outward)
 var new_side = (player.global_position-eva_door_center).dot(eva_outward)
 if old_side * new_side > 0.0 or absf(new_side-old_side) < .0001:
  return
 var crossing = previous.lerp(player.global_position, clampf(-old_side/(new_side-old_side),0.0,1.0))
 if absf((crossing-eva_door_center).dot(eva_tangent)) > .83 or crossing.y < -.16 or crossing.y > .62:
  return
 if not eva_active and new_side > 0.0:
  set_eva(true)
 elif eva_active and new_side < 0.0:
  set_eva(false)

func move_player(dt: float):
 var before = player.global_position
 var move = Vector2.ZERO
 var captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not hands_on_fuse
 if captured:
  move = Vector2(int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A)),int(Input.is_physical_key_pressed(KEY_S))-int(Input.is_physical_key_pressed(KEY_W)))
 if eva_active:
  var lift = 0.0
  if captured:
   lift = float(int(Input.is_physical_key_pressed(KEY_SPACE))-int(Input.is_physical_key_pressed(KEY_CTRL)))
  var thrust = eye.global_transform.basis * Vector3(move.x,0,move.y) + Vector3.UP * lift
  # No gravity or ground snapping. Momentum persists until thrust or braking.
  if captured and Input.is_physical_key_pressed(KEY_R):
   player.velocity = player.velocity.move_toward(Vector3.ZERO, 12.0*dt)
  elif thrust.length_squared() > .001:
   player.velocity = (player.velocity + thrust.normalized()*4.8*dt).limit_length(6.0)
 else:
  var direction = player.global_transform.basis * Vector3(move.normalized().x,0,move.normalized().y)
  var speed = 4.6 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.6
  player.velocity.x = direction.x*speed
  player.velocity.z = direction.z*speed
  if not player.is_on_floor():
   player.velocity.y -= 16.0*dt
  elif player.velocity.y < 0.0:
   player.velocity.y = 0.0
 player.move_and_slide()
 detect_eva_crossing(before)
 if not eva_active and player.global_position.y < -4.0:
  jump_room(room_id)
