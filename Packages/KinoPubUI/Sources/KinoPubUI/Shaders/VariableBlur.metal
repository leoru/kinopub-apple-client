//
//  VariableBlur.metal
//
//  A blur whose radius grows with vertical position, so artwork can stay sharp at
//  the top and dissolve behind overlaid text. Apple's own progressive blurs use a
//  private CAFilter; this is the supported route — a SwiftUI layer effect.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// Samples the layer in a golden-angle spiral whose radius is driven by how far down
/// the view the pixel sits. A spiral spreads the taps evenly, so relatively few of
/// them still read as a smooth blur rather than as rings.
[[ stitchable ]] half4 variableBlur(float2 position,
                                    SwiftUI::Layer layer,
                                    float2 size,
                                    float startPoint,
                                    float maxRadius,
                                    float tapCount) {
  float span = max(1.0 - startPoint, 0.0001);
  float progress = clamp((position.y / max(size.y, 1.0) - startPoint) / span, 0.0, 1.0);

  // Ease in, so the transition out of the sharp region is not a visible line.
  progress = progress * progress;

  float radius = maxRadius * progress;
  if (radius < 0.5) {
    return layer.sample(position);
  }

  const float goldenAngle = 2.39996323;
  int taps = int(tapCount);

  // Accumulate in float: half overflows well before this many samples.
  float4 total = float4(layer.sample(position));
  float weight = 1.0;

  for (int i = 1; i <= taps; ++i) {
    float t = float(i) / float(taps);
    // sqrt spreads samples evenly over the disc's area rather than its radius.
    float sampleRadius = radius * sqrt(t);
    float angle = float(i) * goldenAngle;
    float2 offset = float2(cos(angle), sin(angle)) * sampleRadius;

    total += float4(layer.sample(position + offset));
    weight += 1.0;
  }

  return half4(total / weight);
}
