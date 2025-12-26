[out:json][timeout:300];
(
  // Dive sites - Central America & Mexico
  node["leisure"="dive_centre"](7,-120,25,-80);
  node["sport"="scuba_diving"](7,-120,25,-80);
  // Reefs
  node["natural"="reef"](7,-120,25,-80);
  way["natural"="reef"](7,-120,25,-80);
  // Cenotes (unique to Mexico/Yucatan)
  node["natural"="sinkhole"](17,-92,22,-86);
);
out body;
>;
out skel qt;
