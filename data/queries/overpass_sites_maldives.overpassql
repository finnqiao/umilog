[out:json][timeout:300];
(
  node["leisure"="dive_centre"](-1,72,8,74);
  node["sport"="scuba_diving"](-1,72,8,74);
  node["natural"="reef"](-1,72,8,74);
  way["natural"="reef"](-1,72,8,74);
);
out body;
>;
out skel qt;
