[out:json][timeout:300];
(
  // Dive sites
  node["leisure"="dive_centre"](24,122,46,146);
  node["sport"="scuba_diving"](24,122,46,146);
  // Reefs
  node["natural"="reef"](24,122,46,146);
  way["natural"="reef"](24,122,46,146);
  // Wrecks
  node["historic"="wreck"](24,122,46,146);
);
out body;
>;
out skel qt;
