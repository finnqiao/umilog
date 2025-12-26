[out:json][timeout:300];
(
  // Dive sites - Maldives & Sri Lanka
  node["leisure"="dive_centre"](-2,71,10,82);
  node["sport"="scuba_diving"](-2,71,10,82);
  // Reefs
  node["natural"="reef"](-2,71,10,82);
  way["natural"="reef"](-2,71,10,82);
);
out body;
>;
out skel qt;
