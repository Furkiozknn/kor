# itch.io sayfa metni

İki dil de hazır. **İngilizce önce** öneriliyor: ölçülen yüksek niyetli
etiketler (`horde-survival`, `survivors-like`, `bullet-heaven`) tamamen
İngilizce topluluklar. Türkçe metni altına koy.

---

## Kısa açıklama (tagline, 140 karakter sınırı)

**EN**
```
In the dark you only see as far as you burn. A top-down roguelite where
heat is your sight — and your timer.
```

**TR**
```
Karanlıkta ne kadar görürsen o kadar yakınsın. Isının hem görüşün hem
sayacın olduğu bir top-down roguelite.
```

---

## Uzun açıklama

### EN

**The foundry went cold. You are the last fire left.**

Kor is a 12-minute top-down roguelite built on one rule:

> **Firing heats you. The hotter you run, the more you see.**

The arena is dark. Your heat alone sets how far you can see — from a
blind 40-pixel bubble to the whole foundry. But your weapon heats with
every shot, and at the ceiling it locks. Diving vents your heat and the
screen closes back in: **you pay for safety with sight.**

Nothing explains this to you. The run starts in a dead foundry with one
distant brazier lit. You fire, you warm, the world opens, you find a cold
brazier — and if you are hot enough when you reach it, you light it.
Permanently. The arena is something you build.

**What it asks of you**
- Hold heat for sight, damage and reach — or stay cold and survive
- **POUR** — one charge, one use. Its power scales with your heat, and it
  is the only thing that breaks an overheat lock
- **BRANDS** stick to a weapon for the whole run. Switching weapons means
  leaving everything you built behind
- Five trials unlock content through **skill, not currency** — no run
  where you feel weak because you haven't ground enough
- A **daily pour**: one seed, same foundry for everyone, every day

**Accessibility**: screen shake in three steps or off, hitstop off,
auto-fire, and no information carried by hue alone. Turkish and English.

Free. Plays in the browser.

### TR

**Dökümhane söndü. Elinde kalan tek ateş sensin.**

Kor, tek bir kural üzerine kurulu 12 dakikalık bir top-down roguelite:

> **Ateş etmek ısıtır. Isındıkça daha çok görürsün.**

Arena karanlık. Görüş yarıçapını tek başına ısın belirliyor — kör bir
40 piksellik baloncuktan bütün dökümhaneye kadar. Ama silahın her atışta
ısınıyor ve tavana varınca kilitleniyor. Dalış ısıyı boşaltır, ekran
tekrar kararır: **güvenliği görüşle ödersin.**

Bunu sana kimse anlatmıyor. Koşu sönmüş bir dökümhanede, uzakta yanan tek
bir mangalla başlıyor. Ateş ediyorsun, ısınıyorsun, dünya açılıyor, sönük
bir mangal buluyorsun — ve yanına vardığında yeterince sıcaksan onu
yakıyorsun. Kalıcı olarak. Arena senin inşa ettiğin bir şey.

**Senden istediği**
- Görüş, hasar ve menzil için ısıyı tut — ya da soğuk kal ve hayatta kal
- **DÖKÜM** — tek şarj, tek kullanım. Gücü ısına bağlı ve aşırı ısınma
  kilidini kıran tek şey
- **DAMGA**'lar silaha koşu boyunca yapışır. Silah değiştirmek,
  biriktirdiğin her şeyi geride bırakmak demek
- Beş görev içeriği **parayla değil ustalıkla** açar — yeterince
  biriktirmediğin için güçsüz hissettiğin bir koşu yok
- **Günün dökümü**: tek tohum, herkese aynı dökümhane, her gün

**Erişilebilirlik**: sarsıntı üç kademe ya da kapalı, vuruş donması
kapatılabilir, oto ateş, ve hiçbir bilgi sadece renge yüklenmiyor.
Türkçe ve İngilizce.

Ücretsiz. Tarayıcıda oynanır.

---

## Etiketler (10 tane — ölçülmüş)

```
horde-survival  survivors-like  bullet-heaven  arena  twin-stick-shooter
roguelite  dark  top-down-shooter  roguelike  godot
```

`pixel-art` (198.768 oyun) ve `singleplayer` (307.649) **hak israfı** —
o sayfalarda görünmezsin.

---

## Gömme ayarları — KRİTİK

| ayar | değer | neden |
|---|---|---|
| Kind of project | **HTML** | |
| **SharedArrayBuffer support** | **İŞARETLİ** | `thread_support=true`; işaretlenmezse oyun **hiç açılmaz** |
| Viewport | **1280 × 720** | tam 2×; `scale_mode="integer"` ile bantsız |
| Fullscreen button | açık | |
| Mobile friendly | kapalı | klavye+fare gerekiyor |

## Yüklenecek dosya

`build/web/` klasörünün **içeriği** zip'lenir (klasörün kendisi değil),
`index.html` kökte olmalı.

İndirme boyutu: ~11,4 MB gzip (wasm 9,9 + pck 1,4).

## Görseller

| dosya | yer |
|---|---|
| `tanitim/kapak-315x250.png` | kapak — **üstüne yazı koyma** |
| `tanitim/kor-640.gif` | ekran görüntüsü 1 (animasyonlu) |
| `tanitim/ilk-kare.png` | GIF açılmazsa duran önizleme |

itch GIF'i otomatik oynatmaz — APNG olarak yüklemek ya da GIF'i ekran
görüntüsü alanına koymak gerekiyor.
