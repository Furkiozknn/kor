# Kor

Karanlık bir dökümhanede geçen top-down roguelite. *Vampire Survivors*'ın
sürüsü ile *Enter the Gungeon*'ın el becerisini tek bir kuralda birleştiriyor:

> **Ateş etmek ısıtır. Isındıkça daha çok görürsün.**

## Ayrışma: ısı = görüş

Tür doymuş durumda ve "ateş et, ısın, güçlen" fikri tek başına ayrıştırmıyor —
2026'da bunu yapan başka oyunlar var. Kor'un farkı ısıyı **silah kaynağı**
olmaktan çıkarıp **bilgi kaynağı** yapması:

> Vampire Survivors'ta ekran dolar ve sen izlersin.
> **Kor'da ekran senin ısınla açılır ve kapanır.**

Arena karanlık. Görüş yarıçapını **tek başına ısın** belirliyor:

| Isı | Görüş | Sonuç |
|---|---|---|
| soğuk | 40 px | neredeyse körsün, nereye ateş ettiğini bilmiyorsun |
| sıcak | 300 px | arena açılır, sürüyü görürsün — **ama kilide yaklaşırsın** |
| kilitli | 336 px | her şeyi görürsün, hiçbir şey yapamazsın |

Eğri doğrusal değil: ısının **ilk yarısı görüşün çoğunu** veriyor. Yani
tavana tırmanmak "daha iyi görmek için" yapılmaz — döküm gücü, tavlama ve
kızgın bölge hasarı için yapılır. Bilinçli bir karar, sürüklenilen bir yer değil.

Silahın ısınır; tavana varırsan iki saniye kilitlenir ve **dalış o kilidi
kırmaz.** Kilitliyken görüş *daralmaz* — en geniş halindedir: en parlak,
en kırılgan ve en savunmasız anındasın, düşmanlar ısını sezip hızlanır.
Dalış ısıyı boşaltır → ekran kararır: **güvenliği görüşle ödersin.**

Bu tek kural türün iki bilinen kusurunu birden kapatıyor: durup izlemek
mümkün değil (görmek için ısınmak gerek), ve ekran hiçbir zaman okunamaz
parçacık çorbasına dönmüyor (görünür alan zaten ısıyla sınırlı).

### Isının üç çıkışı

- **Dalış** — ısıyı boşa harcar, seni kurtarır, seni kör bırakır.
- **Kor atışı** (sağ tık) — biriken ısıyı delici hasara çevirir. Ne kadar
  sıcaksan o kadar sert, ama sonrasında soğumuş ve açıktasın.
- **Kor yayılımı** — sıcakken çevreni yakarsın; menzil görüş yarıçapına
  bağlı, yani *gördüğünü yakıyorsun*.

### Arena termodinamiği

Siperler dekor değil, ısı ekonomisinin parçası:

- **Mangal** — ışık adası, yanında görürsün **ama ısınırsın** (+11/sn).
- **Örs** — ışık vermez ama soğumayı **2,6 katına** çıkarır. Kör liman.
- **Fıçı/sandık** — kırılabilir. Ateş hattını açarken ışık adanı da
  yok edebilirsin.

## Kontroller

| Tuş | İş |
|---|---|
| `WASD` / yön tuşları | hareket |
| Sol tık (basılı) | ateş — fareye nişan alır |
| Sağ tık | **kor atışı** — biriken ısıyı delici akkor mermiye çevirir |
| `Boşluk` | dalış (ısıyı boşaltır, dokunulmazlık verir) |
| `E` | **döküm** — şarjlı, tek kullanımlık; gücü ısına bağlı, kilidi kıran tek şey |
| `Q` / `1-4` | silah değiştir |
| `ESC` | duraklat |
| `F11` tam ekran · `C` künye · `G` görevler · `D` günün dökümü | menüde |

## Koşu

**12 dakika.** 30 değil: Kor'da her saniye bir ısı kararı var, 30 dakika
yorar; ayrıca tarayıcıda tek oturumda bitmesi gerekiyor.

Koşu bir eğri değil **bir şekil** (`scripts/dalgalar.gd`): ısınma → basınç →
**nefes** → daha sert basınç → final. Nefes anları zirveleri hissettiriyor ve
kart okuyacak alan açıyor — türün en çok eleştirilen yanı sürekli aynı
basınçtı. 12:00'de dökümhane söner: **kazandın**.

### Silahlar

Dördü de aynı ısı sistemini kullanır; fark ısıyı ne hızda biriktirdikleri.
Silah seçmek "kaç saniyede kilitlenmeyi göze alıyorum" sorusunun cevabı.

| Silah | Karakteri | Kilide kalan |
|---|---|---|
| **Kor Tabancası** | dengeli | ~1.6 sn |
| **Saçma** | 6 saçma, kısa menzil — sürünün içine girmeni ister | ~1.9 sn |
| **Işın** | en yüksek hasar, parmağını kaldırmayı öğretir | ~1.2 sn |
| **Çekiç** | yavaş, delici, sırayı süpürür | ~2.5 sn |

### Düşmanlar

| Tür | Ne yapar |
|---|---|
| **kül** | standart takip |
| **imp** | hızlı, zayıf |
| **iskelet** | dengeli ama sert |
| **koşucu** | **durup ısınır (telegraf), sonra hücum eder** — görüşün genişse erken görürsün |
| **cüruf** | iri, yavaş, 2 hasar |
| **hayalet** | **duvar ve siper tanımaz** |
| **cadı** | mesafesini korur, uzaktan vurur |

Tür listesi bir **ağırlık** listesi: tehlikeli türler seyrek, doldurucular
sık. Ölçüldü — koşucuyu eşit ağırlıkta koymak hayatta kalmayı %43 düşürüyor.

### Patron: Kül Anası

2:30, 6:40 ve 11:30'da uyanır. Can torbası değil, **çekirdek mekaniğin
sınavı**:

- **Işık içer** — sen soğukken kendini onarır ve aldığı hasar %15'e düşer.
  Onu öldürmek için sıcak kalmak, yani kilide yaklaşmak zorundasın.
- **Soğuk dalga** — 13 saniyede bir ısını bir anda söndürür. Kör kalırsın ve
  o karanlıkta üstüne gelir. Mangal coğrafyası burada hayat kurtarır.

### Kartlar ve fırına atma

Her kart **ısı ekonomisinin bir değişkenini** çevirir: ısı tavanı, soğuma,
kilit, görüş menzili, kor atışı bedeli, yayılım. Böylece "doğru silah
gelmedi, koşu öldü" durumu doğmaz.

Beğenmediğin kartı **fırına atabilirsin** (koşu başına 3 hak): yakılan kart
o koşu boyunca bir daha gelmez. Türün en yaygın şikâyeti "yapmak istediğim
şeyi hiç göremedim" idi; VS'in Banish'i bunu yarım çözüyor, bizde kalıcı.

## Silaha yapışan özellikler: DAMGA

Türde alışılmış kalıp geçici güçlendirmedir — 20 saniye sürer, biter,
unutulur. Kor'da tersi: bir damga vurduğun silahta **koşu boyunca kalır.**

Tasarım sonucu şu: damgalar *silaha* bağlandığı için silah değiştirmek
bedava olmaktan çıkıyor. Çekicine üç damga vurduysan `Q`'ya basmak "başka
bir namlu" değil, **biriktirdiğin her şeyi geride bırakmak** demek.

Altı damga (delici, çatal, soğuk namlu, ağır döküm, uzun namlu, kor izi),
silah başına en fazla üç. Havuza yalnızca eldeki silaha *takılabilen*
damgalar girer — "aldım ama işe yaramadı" durumu oluşmaz.

## DÖKÜM — şarjlı, tek kullanımlık

Tür kalıbı "dolunca bas". İki yerde ondan ayrılıyor:

1. **Gücü şarja değil ısına bağlı.** Boşken zayıf, tavana yakınken yıkıcı.
   "Ne zaman basayım" sorusu "ne kadar riske girdim" sorusuyla aynı soru.
2. **Kilidi kıran tek şey.** Dalış bile kırmaz. Aşırı ısındıysan döküm can
   simidin — ama onu o an harcamış olursun.

Menzilindeki sönük mangalları da yakar: döküm dökümhaneyi besler.

## Görevler — içerik parayla değil ustalıkla açılır

Türün en nefret edilen kalıbı "yeterince yükseltme açana kadar 10-15 koşu
boyunca güçsüz hissetmek". Para biriktirmek onu doğurur, görev doğurmaz —
çünkü görevi **oynayarak** geçersin.

Beş görev ve hiçbiri **güç** vermez, hepsi **seçenek** açar: başlangıç
silahı, +1 kart yakma hakkı, döküm ön yüklemesi. İkisi doğrudan ısı
ekonomisinin iki ucunu öğretir (KÖRÜK sıcak, KARANLIĞA ALIŞ soğuk).

## Günün dökümü

Her gün tek tohum, UTC tarihten üretiliyor: dünyanın her yerinde aynı gün
aynı dökümhane. Sunucu gerekmiyor çünkü kıyas zemini **tohum**. Gün
değişince günlük en iyi ve deneme sayacı sıfırlanır.

## Meta ilerleme: fırın kademesi

Koşu sonunda **cüruf** kazanırsın (öldürme × kademe çarpanı). Kalıcı gelişim
**güç değil seçenek** verir — ısı baskısını azaltan hiçbir şey kalıcı değil,
yoksa oyunun çekirdeği söner.

Fırın kademesi 0-3 gönüllü zorluktur ve her basamak **ısının bir ödülünü**
kapatır: kuru mıknatıs (çekim ısıyla büyümez), çatlak pota (döküm artık
kilidi kırmaz), soğuk demir + dar göz (hasar bonusu yok, görüş %20 dar).
Her basamak ayrıca düşmanları güçlendirir ve cüruf çarpanını üsteller.

Bu ilk hali değil: ölçüm merdivenin **ters çalıştığını** gösterdi (kademe 2
oyunu kolaylaştırıyor ve en çok ödüyordu). Sebep, üç değiştiricinin de
ısının *birikim hızına* dokunmasıydı — ama Kor'da ısı ceza değil **ödül**.

## Erişilebilirlik

Bilgi hiçbir yerde *sadece* renge yüklenmiyor:

- Oyuncu **ekranın en parlak nesnesi** ve ısıyla parlaklığı artıyor — gri
  testinde de, renk körlüğünde de "en parlak şey benim" diye okunuyor.
- Düşman çekirdeğinin nabzı **ölçekte**, alfada değil — hareket hiçbir görme
  tipinde kaybolmaz.
- Isı tehlikesi üç kanaldan: doluluk, eşik çizgisi, ve eşik üstünde yanıp
  sönme.
- Karanlıkta düşmanın görünen tek parçası **çekirdeği**, ve yedi tür
  **dört tepki grubuna** ayrılıyor: nabız hızı, genliği ve çekirdek adedi.
  İkisi de renk tonundan bağımsız.

Ayarlardan kapatılabilenler (menüde `HAREKET` satırı):

| ayar | neden |
|---|---|
| sarsıntı tam / yarı / kapalı | 12 dakikalık koşuda ~800 öldürme var; hareket duyarlılığı bir bariyer |
| vuruş donması açık/kapalı | her öldürmede `Engine.time_scale` 0,05'e düşüyordu |
| oto ateş açık/kapalı | 12 dakika sol tuş basılı tutmak fiziksel yük — nişan yine oyuncuda |

Dokunulmazlık yanıp sönmesi **5,9 Hz**: fotosensitif nöbet eşiğinin
(3-60 Hz) yoğun bandının dışında.

Oyun **Türkçe ve İngilizce**. Çeviri anahtarları Türkçe metinlerin
kendisi, yani çeviri dosyası olmasa bile oyun Türkçe çalışmaya devam eder.

## Çalıştırma ve doğrulama

```
godot --path .                      # editörde aç
build/windows/kor.exe               # derlenmiş sürüm

bash tests/dogrula.sh               # TAM DOGRULAMA -- her sey burada
```

`dogrula.sh` sekiz adım çalıştırır — import, ısı, ses, döngü, botlu koşu,
koşu akışı, arayüz taşma, dil kapsamı, menü — ve **herhangi
bir** `ERROR` / `Assertion` / `Parse` satırını başarısızlık sayar. Dar filtre
kullanmaz: geçmişte `grep TAMAM` ile bakarken bir fizik akışı hatası gizli
kalmıştı.

Tek tek:

```
godot --headless --script res://tests/test_isi.gd       # ısı/kilit/dalış kuralları
godot --headless --script res://tests/test_dongu.gd     # uçtan uca oyun döngüsü
godot --script res://tests/ekran_al.gd                  # ekran görüntüsü
godot --script res://tests/ekran_al.gd -- --kart        #   kart ekranı
godot --script res://tests/ekran_al.gd -- --gorus       #   soğuk/sıcak/kilitli
godot --script res://tests/ekran_al.gd -- --zafer       #   kazanma ekranı
godot --script res://tests/ekran_al.gd -- --perf        #   performans ölçümü
```

### Denge ölçüm takımı

Denge tahminle değil ölçümle ayarlanıyor:

```
godot --headless --fixed-fps 60 --script res://tests/denge.gd -- --kosu 10 --sure 740
bash tests/tarama.sh                # parametre taramasi
```

Bot **gerçek oyunu** oynuyor (aynı ateş/ısı/dalış yolları) ve **sadece
gördüğünü biliyor** — ısı=görüş mekaniğini bot da ödemezse ölçüm iyimser
çıkar. `--fixed-fps 60` ile 12 dakikalık koşu ~40 saniyede biter.

Takım üç "makul" varsayımı çürüttü: alan hasarı eklemek hayatta kalmayı
*kötüleştirdi*, oyuncu kuşatılıp ölmüyor (koşu başına 4-7 darbe), ve canı
iki katına çıkarmak neredeyse hiçbir şey değiştirmedi — bağlayıcı kısıt
zorluk rampasıydı.

### Geliştirici katmanı

Hata ayıklama derlemesinde `F1` paneli açar: FPS, ısı, görüş yarıçapı,
evre adı, canlı/tavan, alınan kartlar. `F2` karanlığı kapatır, `F3`
ölümsüzlük, `F4` +30 sn, `F5` dalga, `F6` ısıyı tavana, `F7` seviye atlat,
`F8` bütün silahlar, `F9` temizle, `+/-` zaman ölçeği.

## Performans

Ölçüldü (Intel UHD, GL Compatibility, vsync kapalı, 92 düşman + patron +
dört silah ateş ederken): **ortanca 4,77 ms**, p95 10,6 ms, **bütçe aşan
kare %0**, 187 FPS.

İki gerçek sorun ölçümle bulundu ve çözüldü: mermi izi her 35 ms'de bir yeni
parçacık düğümü ayırıyordu (saniyede ~570 ayırma), ve her patlama düğüm
yaratıyordu. İkisi de havuzlandı.

Karanlık mekaniği `PointLight2D` kullanmıyor: tek tam ekran quad + shader,
24 ışığa kadar sabit maliyet. Ölçülmüştü — gölge açılırsa kare bütçesi
18,49 ms'ye fırlıyor.

## Dosya haritası

| Dosya | İşi |
|---|---|
| `scripts/isi.gd` | çekirdek mekanik, saf mantık — oyundan bağımsız test edilir |
| `scripts/karanlik.gd` + `assets/karanlik.gdshader` | ısı = görüş |
| `scripts/dalgalar.gd` | koşunun şekli: evreler, nefes anları, ağırlıklar |
| `scripts/oyuncu.gd` | hareket, nişan, ateş, dalış, kor atışı, yayılım |
| `scripts/dusman.gd` | yedi tür tek sahnede |
| `scripts/patron.gd` | Kül Anası |
| `scripts/yapi.gd` | siperler ve arena termodinamiği |
| `scripts/ana.gd` | arena, dalga, XP/seviye, kartlar, HUD, paneller |
| `scripts/tema.gd` | görsel dil — tek yerden |
| `scripts/hiss.gd` | oyun hissi: sarsıntı, donma, parçacık havuzu |
| `scripts/kayit.gd` | kalıcı kayıt, cüruf, fırın kademesi, ayarlar |
| `scripts/silahlar.gd` | silah tablosu + DAMGA tanımları |
| `scripts/gorevler.gd` | görev sistemi — içerik ustalıkla açılır |
| `scripts/ses_yonetici.gd` | ses havuzu, katmanlı müzik, ayrı efekt bus'ı |
| `scripts/gelistirici.gd` | F1-F9 geliştirici katmanı (sadece debug) |
| `build/dil/` | çeviri araçları: dize çıkarıcı + tablo birleştirici |
| `build/ses/` | eksik ses olaylarının deterministik üreticisi |

## Varlıklar

- **Oyuncu, patron, düşmanlar** — PixelLab. Tek kare → `create_character` v3
  ile 8 yöne döndürme → `animate_character` ile yürüyüş. Hepsi tek "kül
  fraksiyonu" paletine çekildi; oyuncu tek sıcak nesne.
- **Zemin, siper, kart ikonları, iskelet, hayalet** — [Kenney](https://kenney.nl)
  *Tiny Dungeon*, CC0.
- **Yazı tipi** — PublicPixel, CC0.
- **Ses ve müzik** — sfxr algoritmasıyla kodda üretildi.

Ham (paletlenmemiş) kopyalar `assets/sprites/_ham/` altında.
