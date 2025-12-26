[out:json][timeout:300];
(
  node["leisure"="dive_centre"](-30,130,10,180);
  node["sport"="scuba_diving"](-30,130,10,180);
  node["natural"="reef"](-30,130,10,180);
  way["natural"="reef"](-30,130,10,180);
  node["historic"="wreck"](-30,130,10,180);
);
out body;
>;
out skel qt;
