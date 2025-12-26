[out:json][timeout:300];
(
  // Dive sites - Oceania/Pacific Islands
  node["leisure"="dive_centre"](-30,130,10,180);
  node["sport"="scuba_diving"](-30,130,10,180);
  // Reefs
  node["natural"="reef"](-30,130,10,180);
  way["natural"="reef"](-30,130,10,180);
  // Wrecks
  node["historic"="wreck"](-30,130,10,180);
);
out body;
>;
out skel qt;
