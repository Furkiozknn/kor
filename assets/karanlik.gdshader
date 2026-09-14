shader_type canvas_item;
render_mode blend_mix;

// Dökümhane karanlığı. Tek tam ekran dörtgen; ışık kaynakları bu karanlığı
// deliyor. PointLight2D kullanılmıyor: GL Compatibility'de ışık/gölge
// boru hattı güvenilmez ve gölge açılırsa kare bütçesi patlıyor (ölçüldü:
// 20 ışık + gölge = 18,49 ms). Bu yol tek geçiş, sabit maliyet.

const int TAVAN = 24;

uniform vec2 ekran_boyu = vec2(640.0, 360.0);
uniform int isik_sayisi = 0;
// xy = taban çözünürlükteki ekran konumu, z = yarıçap (piksel)
uniform vec3 isiklar[TAVAN];
// her ışığın kenar yumuşaklığı: 0 = keskin daire, 1 = tamamen yumuşak
uniform float yumusaklik : hint_range(0.05, 1.0) = 0.55;
uniform float karanlik : hint_range(0.0, 1.0) = 0.90;
uniform vec3 golge_rengi : source_color = vec3(0.015, 0.015, 0.035);

void fragment() {
    vec2 p = SCREEN_UV * ekran_boyu;
    float aydinlik = 0.0;
    for (int i = 0; i < TAVAN; i++) {
        if (i >= isik_sayisi) {
            break;
        }
        float r = isiklar[i].z;
        if (r <= 0.0) {
            continue;
        }
        float d = distance(p, isiklar[i].xy);
        // ic yarikta tam aydinlik, disa dogru yumusak sonme
        float a = 1.0 - smoothstep(r * (1.0 - yumusaklik), r, d);
        aydinlik = max(aydinlik, a);
    }
    COLOR = vec4(golge_rengi, karanlik * (1.0 - aydinlik));
}
