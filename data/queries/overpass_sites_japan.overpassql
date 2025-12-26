[out:json][timeout:300];
(
  node["leisure"="dive_centre"](24,122,46,146);
  node["sport"="scuba_diving"](24,122,46,146);
  node["natural"="reef"](24,122,46,146);
  way["natural"="reef"](24,122,46,146);
  node["historic"="wreck"](24,122,46,146);
);
out body;
>;
out skel qt;
