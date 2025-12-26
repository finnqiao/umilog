[out:json][timeout:300];
(
  // Dive sites
  node["leisure"="dive_centre"](-12,95,20,140);
  node["sport"="scuba_diving"](-12,95,20,140);
  // Reefs
  node["natural"="reef"](-12,95,20,140);
  way["natural"="reef"](-12,95,20,140);
  // Wrecks
  node["historic"="wreck"](-12,95,20,140);
  node["seamark:type"="wreck"](-12,95,20,140);
);
out body;
>;
out skel qt;
