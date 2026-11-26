# Kervan ARK-7

Sekizgen basınç halkası biçimindeki araştırma istasyonu için Godot 4 ve Blender projesi.

## Başlatma

1. Proje klasörünü bilgisayarına indir.
2. Godot 4 proje yöneticisinde **Import / İçe Aktar** ile kökteki `project.godot` dosyasını seç.
3. İlk içe aktarma bitince F5 ile ana sahneyi aç.

| Tuş | Kontrol |
|---|---|
| WASD ve fare | Yürüme ve bakış |
| E | Odaktaki parçayla etkileşim |
| F | El feneri |
| Space / Ctrl (EVA) | Yüksel / alçal |
| R (EVA) | Fren |
| Tab | Dış gövde / iç mekan |
| 1–8 | Bölme seçimi |
| H | Yardım |
| Esc | Fareyi bırak |

## Proje dosyaları

- `project.godot` — proje giriş dosyası.
- `istasyon.tscn`, `istasyon.gd` — istasyon sahnesi ve etkileşim prototipi.
- `assetler/` — GLB modeli ve sesler.
- `carpisma.tscn`, `gorevler.json` — çarpışma ve görev konumları.
- `Blender/` — düzenlenebilir Kervan, Eren ve mürettebat kaynak modelleri.
- `tasarim/` — önizleme, görev yerleşimi ve kullanım bilgileri.

Blender kaynaklarını Godot editörünün otomatik içe aktarımından hariç tuttuk. Oyunda kullanılacak model GLB dosyasıdır.

## Durum

Sekiz bölme, altı kamara, dış bakım platformu ve kaçış kapsülü modellenmiştir. Blender ve GLB geometrisi kontrol edilmiştir. Godot çalışma zamanı testi henüz yapılmamıştır. Beş mürettebat üyesi kendi çalışma alanında konumlanır ve E ile konuşulabilir. Hikâye ilerlemesi ve sonlar sonraki geliştirme aşamalarıdır.

## GitHub

Boş bir depo oluşturduktan sonra bu klasörün içeriğini (gizli `.gitignore` dahil) deponun köküne aktar. Godot'un ürettiği geçici dosyalar Git'e eklenmez.

## EVA uçuşu

Hava kilidinde kıyafeti kuşan, iç kapıyı kapat ve dış kapıyı aç. Dış eşiği geçince uçuş otomatik etkinleşir. WASD bakış yönüne göre itki verir. Space/Ctrl dikey hareket, R fren. Tuşu bırakınca hız korunur. Hava kilidinin dış kapısından geri geçince yürüyüş ve yapay yer çekimi geri gelir.
