[out:json][timeout:300];
(
  node["leisure"="dive_centre"](7,-120,25,-80);
  node["sport"="scuba_diving"](7,-120,25,-80);
  node["natural"="reef"](7,-120,25,-80);
  way["natural"="reef"](7,-120,25,-80);
  node["natural"="sinkhole"](17,-92,22,-86);
);
out body;
>;
out skel qt;
