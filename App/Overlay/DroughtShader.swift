/// Code du shader de sécheresse, compilé au lancement par Metal.
///
/// Compilé à l'exécution plutôt qu'au build : la compilation hors ligne exige la « Metal Toolchain »,
/// un téléchargement séparé d'Xcode 27. Les aperçus de debug (`-GorgeeRenderPreview`) l'exercent.
enum DroughtShader {
    static let source = """
#include <metal_stdlib>
using namespace metal;

// Déforme une copie de l'écran : mirage de chaleur, plaques d'argile qui décalent chacune
// leur éclat de contenu, contenu aspiré dans les fissures, puis argile qui recouvre tout.
// Coordonnées en points, origine en haut à gauche, comme MudTiling.

struct DroughtUniforms {
    float2 viewSize;
    float2 cellSize;
    float severity;
    float time;
    float rampWidth;
    int columns;
    int rows;
};

struct MudSite {
    float2 position;
    float reveal;
    float shade;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut droughtVertex(uint vertexID [[vertex_id]]) {
    const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 corner = corners[vertexID];
    VertexOut out;
    out.position = float4(corner, 0, 1);
    out.uv = float2((corner.x + 1) * 0.5, 1 - (corner.y + 1) * 0.5);
    return out;
}

fragment float4 droughtFragment(VertexOut in [[stage_in]],
                                texture2d<float> screen [[texture(0)]],
                                constant DroughtUniforms &u [[buffer(0)]],
                                const device MudSite *sites [[buffer(1)]]) {
    constexpr sampler linearSampler(address::clamp_to_edge, filter::linear);
    float2 p = in.uv * u.viewSize;
    float s = u.severity;

    // Plaque du pixel : germe le plus proche (F1) et le suivant (F2) parmi les 3×3 cases voisines.
    int2 cell = int2(floor(p / u.cellSize));
    float d1 = 1e9;
    float d2 = 1e9;
    int nearest = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int2 c = cell + int2(dx, dy);
            if (c.x < 0 || c.y < 0 || c.x >= u.columns || c.y >= u.rows) continue;
            int index = c.y * u.columns + c.x;
            float d = distance(p, sites[index].position);
            if (d < d1) { d2 = d1; d1 = d; nearest = index; }
            else if (d < d2) { d2 = d; }
        }
    }
    MudSite plate = sites[nearest];
    float dryness = s >= 1 ? 1 : clamp((s - plate.reveal) / u.rampWidth, 0.0, 1.0);
    float edge = (d2 - d1) * 0.5; // distance approximative à la fissure

    // 1. Mirage de chaleur : les lignes ondulent dès 30 % de sécheresse, de plus en plus fort.
    float shimmerLevel = smoothstep(0.3, 1.0, s);
    float shimmer = 9.0 * shimmerLevel;
    float2 offset = float2(sin(p.y * 0.045 + u.time * 2.1) + 0.5 * sin(p.y * 0.11 - u.time * 3.3),
                           0.35 * sin(p.x * 0.05 + u.time * 1.7)) * shimmer;

    // 2. Éclats : chaque plaque sèche décale son morceau d'écran dans sa propre direction.
    float angle = plate.shade * 6.2831853;
    offset += float2(cos(angle), sin(angle)) * dryness * u.cellSize.x * 0.32;

    // 3. Fissures : le contenu proche du bord est aspiré vers l'intérieur de la plaque.
    float2 inward = normalize(plate.position - p + 1e-4);
    offset += inward * dryness * smoothstep(14.0, 0.0, edge) * 12.0;

    float4 content = screen.sample(linearSampler, (p + offset) / u.viewSize);

    // Couleurs qui fanent vers le sable.
    float gray = dot(content.rgb, float3(0.299, 0.587, 0.114));
    float3 sand = float3(0.80, 0.64, 0.42);
    float3 color = mix(content.rgb, mix(float3(gray), sand, 0.5), dryness * 0.65);

    // 4. L'argile recouvre : jusqu'à 95 % à sévérité maximale.
    float3 clayDark = float3(0.72, 0.55, 0.36);
    float3 clayLight = float3(0.87, 0.75, 0.56);
    float bulge = 1.0 - smoothstep(0.0, u.cellSize.x * 0.6, d1); // plaque bombée, plus claire au centre
    float3 clay = mix(mix(clayDark, clayLight, plate.shade * 0.6), clayLight, bulge * 0.5);
    float cover = dryness * dryness * (0.25 + 0.70 * s);
    color = mix(color, clay, cover);

    // Fissure sombre entre les plaques.
    float crackWidth = 1.0 + 3.0 * dryness;
    float crack = (1.0 - smoothstep(crackWidth, crackWidth + 1.5, edge)) * dryness;
    color = mix(color, float3(0.24, 0.15, 0.08), crack * 0.9);

    // Là où rien ne bouge encore, on laisse voir le vrai écran (pas de latence).
    float active = max(step(1e-4, dryness), step(1e-4, shimmerLevel));
    return float4(color * active, active);
}
"""
}
