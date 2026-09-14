# Kor

Top-down roguelite. *Vampire Survivors*'ın sürüsü ile *Enter the Gungeon*'ın
el becerisini tek bir düğmede birleştiriyor: **ateş etmek ısı biriktirir.**

## Çekirdek mekanik: ısı ve dalış

```
  ateş et  →  ısı ↑ ↑ ↑  →  KİLİT (2 sn savunmasız)
                 ↓
              DALIŞ  →  ısı = 0, dokunulmazlık
```

Silahın ısınır. Tavana varırsan iki saniye boyunca ateş edemezsin — ve
**dalış seni o kilitten kurtarmaz.** Yani dalış hem kaçınma hem yeniden
yükleme: sürünün içine zamanında dalarsan ısın sıfırlanır, geç kalırsan
sürünün ortasında kilitli kalırsın. Oyunun bütün gerilimi şu tek soruda:
*bir mermi daha mı, yoksa şimdi mi dalayım?*

Ve ısı sadece tehdit değil, aynı zamanda **kaynak**: sağ tıkla kor atışı
yaparsan biriken ısı hasara dönüşür (ne kadar sıcaksan o kadar sert, düşman
delip geçer) ama ısın sıfırlanır. Aynı kaynağın iki çıkışı var — dalış onu
boşa harcar ve seni kurtarır, kor atışı onu hasara çevirir ama seni orada
bırakır. Isı göstergesindeki sarı çizgi kor atışı eşiği.

Kartlar bu ikilemi büker — ısı tavanını büyütmek, soğumayı hızlandırmak,
ya da tam tersi: ısı yüksekken hasar veren "kızgın çelik" ile kilidin
kenarında oynamayı ödüllendirmek.

## Kontroller

| Tuş | İş |
|---|---|
| `WASD` / yön tuşları | hareket |
| Sol tık (basılı) | ateş — fareye nişan alır |
| Sağ tık | **kor atışı** — biriken ısıyı delici bir akkor mermiye çevirir |
| `Boşluk` | dalış (ısıyı boşaltır, dokunulmazlık verir) |
| `Q` / `1-4` | silah değiştir (birden fazla açıksa) |
| `R` | öldükten sonra yeniden başla |

## Silahlar

Dördü de **aynı ısı sistemini** kullanır; fark, ısıyı ne hızda biriktirdikleri.
Silah seçmek aslında "kaç saniyede kilitlenmeyi göze alıyorum" sorusunun cevabı.
Başlangıçta sadece tabanca açık, diğerleri kart olarak çıkar.

| Silah | Karakteri | Kilide kalan |
|---|---|---|
| **Kor Tabancası** | dengeli, her işi görür | ~1.6 sn |
| **Saçma** | 6 saçma, kısa menzil, yıkıcı — sürünün içine girmeni ister | ~1.9 sn |
| **Işın** | en yüksek hasar, parmağını kaldırmayı öğreten silah | ~1.2 sn |
| **Çekiç** | yavaş, delici, sırayı süpürür | ~2.5 sn |

## Koşu döngüsü

Düşman öl → XP küpü düşer → mıknatıs menzilinde sana akar → seviye →
3 karttan biri. Süre geçtikçe dalgalar sıklaşır, düşmanlar sertleşir ve
yeni türler devreye girer.

### Düşmanlar

| Tür | Ne yapar | Ne zaman |
|---|---|---|
| **kül** | standart takip | baştan |
| **imp** | hızlı, zayıf | 15. saniye |
| **iskelet** | dengeli ama sert, 2 XP | 30. saniye |
| **cüruf** | iri, yavaş, 2 hasar, 3 XP | 45. saniye |
| **hayalet** | **duvar ve siper tanımaz**, hızlı, 2 XP | 60. saniye |
| **cadı** | mesafesini korur, uzaktan mermi atar, 3 XP | 75. saniye |

Hayalet oyunun siper mantığını bozmak için var: bir köşeye yerleşip
sürüyü fıçıların arkasında tutmak 60. saniyeden sonra işe yaramaz. Cadı
ise tersini yapar — yaklaşırsan geri çekilir, uzaktan vurur. İkisi birlikte
"tek bir güvenli nokta" diye bir şey bırakmıyor.

### Arena ve siperler

Arena her koşuda yeniden kuruluyor: 40×22 karo zemin, çevresi çarpışmalı
duvar, içine 14 siper serpiliyor. **Fıçı, sandık ve fıçı yığını kırılabilir**
— ateş hattını sen açarsın, kırınca XP düşer. **Örs ve mangal kalıcı**:
mermiyi de sürüyü de durdurur, ama kırılmaz.

## Çalıştırma

```
godot --path .                      # editörde aç
build/windows/kor.exe               # derlenmiş sürüm
```

Testler (ikisi de headless, saniyeler sürer):

```
godot --headless --script res://tests/test_isi.gd     # ısı/kilit/dalış kuralları
godot --headless --script res://tests/test_dongu.gd   # arena, siper, 5 tür,
                                                      # spawn -> hasar -> küp -> XP -> kart
godot --script res://tests/ekran_al.gd                # gerçek render'ı PNG'ye yazar
```

## Dosya haritası

| Dosya | İşi |
|---|---|
| `scripts/isi.gd` | çekirdek mekanik, saf mantık — oyundan bağımsız test edilir |
| `scripts/oyuncu.gd` | hareket, nişan, ateş, dalış, hasar |
| `scripts/dusman.gd` | takip + temas hasarı, beş tür tek sahnede |
| `scripts/yapi.gd` | arena siperleri, kırılabilir ve kalıcı |
| `scripts/mermi.gd` | mermi uçuşu ve çarpışma |
| `scripts/kup.gd` | XP küpü + mıknatıs |
| `scripts/ana.gd` | arena kurulumu, dalga doğurma, XP/seviye, kart ekranı, HUD |

## Oyun hissi

`scripts/hiss.gd` (autoload `Hiss`) tek bir varlık dosyası kullanmadan,
hepsi kodla: kamera sarsıntısı, ağır darbelerde vuruş donması, parçacık
patlamaları, dalış hayaletleri, yarıçapsal parlama dokuları ve toplamalı
karışım. Ateş ederken geri tepme, namlu alevi ve kamera sarsıntısı var;
vurulan düşman eziliyor ve geri itiliyor; ölünce kül patlıyor. Düşmanlar
yoktan bitmiyor, büyüyerek geliyor.

## Görsel kimlik

Sıcak ve soğuk. Oyuncu tek sıcak şey: karanlık dökümhanede ateş eden,
altında ısıyla büyüyen bir kor parlaması taşıyan figür. Mangallar zemine
sıcak ışık havuzları döküyor, kenarları vinyet karartıyor. Bütün düşmanlar tek "kül fraksiyonu"
paletinde — gri-camgöbeği, soğuk. Isın yükseldikçe halkan büyür ve
beyazlaşır; ısı göstergesine bakmadan da nerede olduğunu görürsün.

## Animasyon

Oyuncu **8 yöne dönüyor ve gerçek 8 kareli yürüyüş** oynatıyor; nişan aldığın
yöne bakar, hızına göre adım temposu değişir, dururken duruş karesine döner.
Altı düşman türünün her birinin kendi 8 kareli döngüsü var — kül sürüklenerek,
imp seğirterek, iskelet katı adımlarla, hayalet süzülerek, cadı asasını
kaldırarak, cüruf ağır ağır yalpalayarak.

`SpriteFrames` kaynakları **kodda** kuruluyor (`scripts/yonlu.gd`), `.tres`
olarak elle yazılmıyor — BOM'lu dosya yazıp Godot ayrıştırıcısını çökertme
sınıfı hata böylece hiç doğmuyor. Düşman kareleri tür başına bir kez kurulup
önbelleğe alınıyor, 60 düşman aynı anda doğsa bile yeniden kurulmuyor.

## Varlıklar

- **Oyuncu** — PixelLab. Önce `create_image_pixen` ile tek kare, sonra
  `create_character` v3 referans modu o kareyi 8 yöne döndürdü (1 generation),
  `animate_character` şablon modu 8 yönün her birine yürüyüş verdi
  (yön başına 1 generation). Kareler `assets/sprites/oyuncu/`.
- **Düşman animasyonları** — `animate_image`, tür başına 1 generation,
  `assets/sprites/anim/`. Ham tek kareler `assets/sprites/_ham/` altında.
- **Zemin, duvar, siperler, kart ikonları, iskelet ve hayalet** —
  [Kenney](https://kenney.nl) *Tiny Dungeon* (CC0), paleti oyunun
  fraksiyonuna uyacak şekilde değiştirildi.

## Durum

Oynanabilir dikey dilim. Tek arena, dört silah + kor atışı, on iki kart
ve üç silah kartı, altı düşman türü.

Sırada: ses (ayrı oturumda), 8 yönlü sprite ve yürüme animasyonu, patron.
