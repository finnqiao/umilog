#!/usr/bin/env python3
"""
Part E — additional extra sites to reach ~2,000 total.
"""

EXTRA_SITES_E: dict[str, list] = {

    # ── Malaysia / Borneo ──────────────────────────────────────────────────
    "tioman-east-coast-malaysia": [
        ("Tiger Reef", "Reef", "Intermediate", ["reef fish", "sharks", "coral"], ["big-animals"]),
        ("Renggis Island", "Reef", "Beginner", ["reef fish", "turtles", "coral"], ["beginner-friendly"]),
        ("Chebeh Island", "Reef", "Advanced", ["current", "pelagic", "reef fish"], ["advanced-challenges"]),
        ("Salang Point", "Reef", "Beginner", ["reef fish", "coral", "turtles"], ["beginner-friendly"]),
        ("Labas Island", "Reef", "Intermediate", ["reef", "fish diversity"], []),
        ("Tokong Bahara", "Reef", "Advanced", ["current", "grouper", "pelagic"], ["advanced-challenges"]),
        ("Paya Wreck", "Wreck", "Beginner", ["shallow wreck", "reef fish", "coral"], ["wreck-capitals", "beginner-friendly"]),
        ("Mangkuk Reef", "Reef", "Intermediate", ["reef fish", "soft coral", "macro"], []),
        ("Golden Reef", "Reef", "Intermediate", ["hard coral", "reef fish"], []),
    ],
    "brunei-reefs-wrecks": [
        ("Bunga Mas 5 Wreck", "Wreck", "Intermediate", ["wreck", "reef fish", "coral growth"], ["wreck-capitals"]),
        ("Bunga Mas 6 Wreck", "Wreck", "Intermediate", ["wreck", "reef fish"], ["wreck-capitals"]),
        ("Pelong Rocks", "Reef", "Intermediate", ["reef", "fish diversity", "current"], []),
        ("Tokong Bahara Brunei", "Reef", "Advanced", ["remote reef", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Tudong Reef", "Reef", "Beginner", ["reef fish", "coral"], ["beginner-friendly"]),
        ("Ranggu Caves", "Cave", "Intermediate", ["cavern", "reef fish", "macro"], ["caves-cenotes"]),
        ("Muara Beach Reef", "Shore", "Beginner", ["shore", "macro", "reef fish"], ["beginner-friendly"]),
    ],
    "sabah-northern-borneo": [
        ("Pulau Kalampunian Besar", "Reef", "Intermediate", ["reef", "turtles", "reef fish"], []),
        ("Pulau Mansalar", "Reef", "Intermediate", ["whale sharks seasonal", "reef fish"], ["big-animals"]),
        ("Pulau Pom Pom", "Reef", "Beginner", ["coral garden", "reef fish", "macro"], ["beginner-friendly"]),
        ("Mataking Island", "Reef", "Beginner", ["calm reef", "turtles", "reef fish"], ["beginner-friendly"]),
        ("Pandanan Island", "Reef", "Intermediate", ["reef", "fish diversity", "sharks"], ["big-animals"]),
        ("Pulau Tiga", "Shore", "Beginner", ["shore", "reef fish", "shore diving"], ["beginner-friendly"]),
        ("Kulambu Reef", "Reef", "Intermediate", ["reef fish", "soft coral", "current"], []),
        ("Innamincka", "Reef", "Intermediate", ["reef", "macro", "fish"], []),
    ],

    # ── East Africa & Arabia ───────────────────────────────────────────────
    "kenya-zanzibar": [
        ("Leven Bank Outer", "Reef", "Advanced", ["remote", "hammerheads", "pristine"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Fungu Mkazi Reef", "Reef", "Intermediate", ["reef fish", "coral", "turtles"], []),
        ("Chumbe Reef Extension", "Reef", "Beginner", ["marine sanctuary", "reef fish"], ["beginner-friendly"]),
        ("Stone Town Reef", "Reef", "Beginner", ["reef fish", "history nearby", "coral"], ["beginner-friendly"]),
        ("Nakupenda Sandbank", "Shore", "Beginner", ["sandbank", "snorkel", "reef fish"], ["beginner-friendly"]),
        ("Misali Island", "Reef", "Intermediate", ["reef fish", "sharks", "turtles"], ["big-animals"]),
        ("Latham Island", "Reef", "Advanced", ["remote", "sharks", "whale sharks seasonal"], ["big-animals", "liveaboard"]),
        ("Mafia Island", "Reef", "Intermediate", ["whale sharks", "reef fish", "coral"], ["big-animals"]),
        ("Whale Shark Reef Mafia", "Reef", "Intermediate", ["whale sharks", "seasonal aggregation"], ["big-animals"]),
    ],
    "mozambique-channel": [
        ("Manta Reef Vilanculos", "Reef", "Intermediate", ["manta rays", "reef fish", "turtles"], ["big-animals"]),
        ("Two Mile Reef Vilanculos", "Reef", "Intermediate", ["reef", "fish diversity"], []),
        ("Benguerra Island", "Reef", "Intermediate", ["reef", "turtles", "dugong"], ["big-animals"]),
        ("Pomene Outer Reef", "Reef", "Advanced", ["remote", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Ponta Malongane", "Shore", "Intermediate", ["shore", "reef fish", "macro"], []),
        ("Ponta do Ouro", "Shore", "Advanced", ["dolphins", "sharks", "shore"], ["big-animals", "advanced-challenges"]),
        ("Santa Maria Reef", "Reef", "Intermediate", ["reef fish", "coral", "turtles"], []),
    ],

    # ── South America ──────────────────────────────────────────────────────
    "fernando-de-noronha": [
        ("Morro do Pico", "Reef", "Intermediate", ["reef fish", "dolphins", "reef"], ["big-animals"]),
        ("Piranha Dive", "Reef", "Intermediate", ["schooling reef fish", "unique", "current"], []),
        ("Pedra Assentada", "Reef", "Advanced", ["current", "pelagic", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Ponta da Sapata North", "Wall", "Advanced", ["wall", "current", "reef sharks"], ["big-animals", "advanced-challenges"]),
        ("Calheta Funda", "Cave", "Intermediate", ["cavern", "fish", "clear water"], ["caves-cenotes"]),
        ("Kiosque", "Reef", "Intermediate", ["reef fish", "turtles", "reef"], []),
        ("Cagarras da Seca", "Reef", "Intermediate", ["reef", "fish diversity", "turtles"], []),
    ],
    "brazil-northeast": [
        ("Parrachos de Maracajaú Deep", "Reef", "Intermediate", ["outer reef", "sharks", "fish"], ["big-animals"]),
        ("Costão de Itacoatiara", "Shore", "Intermediate", ["shore", "reef fish", "macro"], []),
        ("Arraial do Cabo", "Reef", "Advanced", ["cold upwelling", "visibility", "fish density"], ["advanced-challenges"]),
        ("Ilha Grande Reefs", "Reef", "Intermediate", ["reef", "fish diversity", "clear water"], []),
        ("Búzios Outer Reefs", "Reef", "Intermediate", ["reef", "pelagic", "fish diversity"], []),
        ("Abrolhos South Reefs", "Reef", "Advanced", ["remote", "pristine", "humpback whales"], ["big-animals", "advanced-challenges"]),
        ("Santa Cruz Coral Reef", "Reef", "Beginner", ["only coral reef in Atlantic S America", "unique", "fish"], ["beginner-friendly"]),
    ],
    "colombia-venezuela-caribbean": [
        ("Serrana Bank", "Reef", "Advanced", ["remote atoll", "sharks", "pristine"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Roncador Cay", "Reef", "Advanced", ["remote", "sharks", "pristine"], ["big-animals", "liveaboard"]),
        ("Quitasueño Bank", "Reef", "Advanced", ["remote", "sharks", "reef fish"], ["big-animals", "liveaboard"]),
        ("Bahía de Pozos Colorados", "Reef", "Intermediate", ["reef fish", "coral", "wreck"], []),
        ("Boca Grande Cartagena", "Shore", "Beginner", ["shore", "reef fish", "history nearby"], ["beginner-friendly"]),
        ("Catalina Island Colombia", "Reef", "Intermediate", ["reef fish", "sharks", "clear water"], ["big-animals"]),
    ],
    "patagonia-chile": [
        ("Rapa Nui (Easter Island)", "Reef", "Intermediate", ["moai underwater", "endemic fish", "unique"], []),
        ("Juan Fernandez Archipelago", "Reef", "Advanced", ["fur seals", "endemic species", "remote"], ["big-animals", "liveaboard"]),
        ("Cabo de Hornos", "Shore", "Advanced", ["extreme location", "kelp", "unique"], ["cold-water", "advanced-challenges"]),
        ("Strait Magellan Narrows", "Drift", "Advanced", ["strong tidal current", "kelp", "unique"], ["cold-water", "advanced-challenges"]),
        ("Puerto Natales Fjords", "Shore", "Advanced", ["cold water", "kelp forest", "seals"], ["cold-water", "advanced-challenges"]),
        ("Atacama Desert Coast", "Shore", "Intermediate", ["cold upwelling", "sea lions", "unique desert coast"], ["big-animals", "cold-water"]),
    ],

    # ── Cold Water / North Atlantic ────────────────────────────────────────
    "northeast-usa": [
        ("Gay Head Clay Cliffs", "Shore", "Intermediate", ["cold water", "striped bass area", "reef fish"], ["cold-water"]),
        ("Block Island", "Shore", "Intermediate", ["cold water", "reef fish", "lobster"], ["cold-water"]),
        ("Nantucket Shoals", "Reef", "Intermediate", ["cold Atlantic", "reef fish", "lobster"], ["cold-water"]),
        ("Graves Ledge Boston", "Reef", "Advanced", ["current", "cold water", "reef fish", "lobster"], ["cold-water", "advanced-challenges"]),
        ("Fort Wetherill RI", "Shore", "Intermediate", ["cold water", "reef fish", "macro"], ["cold-water"]),
    ],
    "norway-lofoten": [
        ("Vesteralen Orcas", "Reef", "Advanced", ["orca herding herring", "Arctic cold", "unique"], ["big-animals", "cold-water", "advanced-challenges"]),
        ("Bodø Reefs", "Shore", "Intermediate", ["kelp", "cold water", "fish"], ["cold-water"]),
        ("Harstad Wreck", "Wreck", "Intermediate", ["WWII wreck", "cold water", "cod"], ["wreck-capitals", "cold-water"]),
    ],
    "scotland-uk": [
        ("Scapa Flow Kronprinz Wilhelm", "Wreck", "Intermediate", ["WWI battleship", "history", "cold water"], ["wreck-capitals", "cold-water"]),
        ("Scapa Flow SMS Markgraf", "Wreck", "Intermediate", ["WWI battleship", "cold water", "history"], ["wreck-capitals", "cold-water"]),
        ("Scapa Flow Coln Wreck", "Wreck", "Beginner", ["shallow wreck", "reef fish", "cold water"], ["wreck-capitals", "cold-water", "beginner-friendly"]),
        ("Trewavas Head Cornwall", "Shore", "Intermediate", ["grey seals", "cold water", "reef fish"], ["big-animals", "cold-water"]),
        ("Porthkerris Cove", "Shore", "Intermediate", ["shore", "reef fish", "cold water", "macro"], ["cold-water"]),
        ("Lizard Point", "Shore", "Advanced", ["current", "cold water", "reef fish"], ["cold-water", "advanced-challenges"]),
        ("Manacles Reef", "Reef", "Intermediate", ["wrecks", "reef fish", "cold water"], ["wreck-capitals", "cold-water"]),
    ],
    "ireland-west-coast": [
        ("Aran Islands Reef", "Shore", "Intermediate", ["cold water", "reef fish", "kelp"], ["cold-water"]),
        ("Connemara Sea", "Shore", "Intermediate", ["cold water", "macro", "reef fish"], ["cold-water"]),
        ("Baltimore Harbour", "Shore", "Beginner", ["shore", "reef fish", "cold water"], ["cold-water", "beginner-friendly"]),
        ("Skull Rock", "Reef", "Intermediate", ["cold water", "reef fish", "macro"], ["cold-water"]),
        ("Fastnet Rock", "Reef", "Advanced", ["remote", "seals", "basking sharks", "current"], ["big-animals", "cold-water", "advanced-challenges"]),
    ],
    "canada-pacific": [
        ("Agamemnon Channel", "Reef", "Intermediate", ["sponges", "rockfish", "cold water"], ["cold-water"]),
        ("Saltery Bay", "Shore", "Beginner", ["mermaid statue", "shore", "reef fish", "cold water"], ["cold-water", "beginner-friendly"]),
        ("Powell River", "Shore", "Beginner", ["shore", "reef fish", "cold water"], ["cold-water", "beginner-friendly"]),
        ("Campbell River", "Drift", "Advanced", ["strong current", "Pacific salmon", "cold water"], ["cold-water", "advanced-challenges"]),
        ("Desolation Sound", "Shore", "Intermediate", ["prawns", "reef fish", "kelp", "cold water"], ["cold-water"]),
    ],

    # ── Japan & East Asia ──────────────────────────────────────────────────
    "hokkaido-northern-japan": [
        ("Daisetsuzan Coast", "Shore", "Intermediate", ["cold Pacific", "kelp", "unique fauna"], ["cold-water"]),
        ("Uchiura Bay", "Shore", "Intermediate", ["macro", "nudibranchs", "cold water"], ["macro-muck", "cold-water"]),
        ("Cape Kiritappu", "Shore", "Advanced", ["remote", "cold water", "unique fauna"], ["cold-water", "advanced-challenges"]),
        ("Toya Lake", "Shore", "Intermediate", ["freshwater lake", "unique", "cold water"], ["cold-water"]),
    ],
    "izu-peninsula-japan": [
        ("Shimoda", "Shore", "Intermediate", ["macro", "sea slugs", "reef fish"], ["macro-muck"]),
        ("Takane", "Shore", "Intermediate", ["macro", "ghost pipefish", "reef fish"], ["macro-muck"]),
        ("Heda Bay", "Shore", "Beginner", ["calm", "reef fish", "macro"], ["beginner-friendly"]),
        ("Tago", "Shore", "Intermediate", ["macro", "nudibranchs", "seahorse"], ["macro-muck"]),
        ("Kichijima", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
    ],
    "okinawa-japan": [
        ("Odo Beach", "Shore", "Beginner", ["shore", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Zamami Island", "Reef", "Intermediate", ["reef fish", "clear water", "turtles"], []),
        ("Aguni Island", "Reef", "Intermediate", ["remote island", "reef fish", "clear water"], []),
        ("Izena Island", "Reef", "Intermediate", ["reef", "schooling fish", "coral"], []),
        ("Sesoko Island", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
    ],
    "taiwan": [
        ("Yonaguni Hammerhead Extension", "Reef", "Advanced", ["hammerheads", "seasonal", "current"], ["big-animals", "advanced-challenges"]),
        ("Lanyu (Orchid Island) Night", "Shore", "Beginner", ["night diving", "flying fish", "unique"], ["beginner-friendly"]),
        ("Xiaoliuqiu Night Turtles", "Shore", "Beginner", ["night diving", "turtles", "shore"], ["big-animals", "beginner-friendly"]),
        ("Wanli Reefs Taiwan", "Reef", "Intermediate", ["reef fish", "macro", "coral"], []),
    ],

    # ── South Africa / South Atlantic ─────────────────────────────────────
    "south-africa-eastern-cape": [
        ("Landers Reef", "Reef", "Advanced", ["ragged tooth sharks", "bull sharks", "deep"], ["big-animals", "advanced-challenges"]),
        ("Scottburgh Reef", "Reef", "Intermediate", ["reef fish", "turtles", "coral"], []),
        ("Ballito Reefs", "Reef", "Intermediate", ["reef fish", "blacktip sharks", "turtles"], ["big-animals"]),
        ("Umzumbe Reef", "Reef", "Intermediate", ["reef fish", "turtles", "sharks"], ["big-animals"]),
        ("Thundercat Site", "Reef", "Advanced", ["ragged tooth sharks", "tiger sharks", "deep"], ["big-animals", "advanced-challenges"]),
        ("Bass City", "Reef", "Intermediate", ["reef fish", "potato bass", "reef"], ["big-animals"]),
        ("Green Point Reef Durban", "Reef", "Beginner", ["reef fish", "turtles", "beginners"], ["beginner-friendly"]),
    ],
    "south-africa-western-cape": [
        ("Millers Point", "Shore", "Intermediate", ["cold water", "reef fish", "seals"], ["cold-water", "big-animals"]),
        ("Shelly Beach Cape Town", "Shore", "Beginner", ["shore", "cold water", "reef fish"], ["cold-water", "beginner-friendly"]),
        ("Long Beach Simonstown", "Shore", "Intermediate", ["sandy", "seahorse", "macro", "cold water"], ["macro-muck", "cold-water"]),
        ("Paw Paw Caves False Bay", "Cave", "Intermediate", ["cavern", "cold water", "reef fish"], ["caves-cenotes", "cold-water"]),
        ("Duiker Island Seals", "Shore", "Intermediate", ["cape fur seals", "cold water", "snorkel"], ["big-animals", "cold-water"]),
    ],
    "mozambique-north": [
        ("Runde National Reserve", "Reef", "Advanced", ["remote", "pristine", "sharks", "whale sharks"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Tofo Outer Reef", "Reef", "Advanced", ["whale sharks", "mantas", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Guinjata Bay", "Shore", "Intermediate", ["shore diving", "reef fish", "turtles"], []),
    ],

    # ── Australia & New Zealand ────────────────────────────────────────────
    "south-australia-victoria": [
        ("Pt Noarlunga Outer Reef", "Reef", "Intermediate", ["reef fish", "cold water", "macro"], ["cold-water"]),
        ("Victor Harbor Reefs", "Reef", "Intermediate", ["cold water", "reef fish", "kelp"], ["cold-water"]),
        ("Kangaroo Island Seals", "Shore", "Intermediate", ["sea lions", "reef fish", "cold water"], ["big-animals", "cold-water"]),
        ("Weedy Sea Dragon Hotspot", "Shore", "Beginner", ["weedy sea dragons", "macro", "shore"], ["macro-muck", "beginner-friendly"]),
        ("Portsea Pinnacle", "Reef", "Intermediate", ["pinnacle", "reef fish", "cold water"], ["cold-water"]),
        ("Popes Eye", "Reef", "Intermediate", ["artificial reef", "seals", "cold water"], ["big-animals", "cold-water"]),
    ],
    "western-australia": [
        ("Busselton Jetty", "Shore", "Beginner", ["world's longest jetty", "reef fish", "macro"], ["beginner-friendly"]),
        ("HMAS Swan Wreck", "Wreck", "Intermediate", ["navy destroyer", "reef fish", "western australia"], ["wreck-capitals"]),
        ("Shoalwater Islands", "Shore", "Intermediate", ["sea lions", "reef fish", "dugong"], ["big-animals"]),
        ("Jurien Bay", "Shore", "Intermediate", ["sea lions", "reef fish", "clear water"], ["big-animals", "beginner-friendly"]),
        ("Lancelin Cray Caves", "Cave", "Intermediate", ["crayfish", "cave", "unique"], ["caves-cenotes"]),
        ("Exmouth Navy Pier", "Shore", "Advanced", ["jetty", "wobbegongs", "reef fish density", "macro"], ["macro-muck", "advanced-challenges"]),
        ("Coral Gardens Exmouth", "Reef", "Beginner", ["coral garden", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Osprey Bay Exmouth", "Reef", "Intermediate", ["reef fish", "whale sharks seasonal", "turtles"], ["big-animals"]),
    ],
    "lord-howe-norfolk": [
        ("Balls Pyramid Deep Wall", "Wall", "Advanced", ["wall", "pelagic", "unique remote"], ["advanced-challenges", "liveaboard"]),
        ("Comets Hole", "Reef", "Intermediate", ["reef fish", "endemic", "clear water"], []),
        ("North Bay Snorkel Reef", "Shore", "Beginner", ["snorkel", "reef fish", "endemic", "clearest water"], ["beginner-friendly"]),
        ("Old Settlement Beach", "Shore", "Beginner", ["reef fish", "endemic species", "turtles"], ["beginner-friendly"]),
    ],
    "vanuatu": [
        ("Big Bay Santo", "Shore", "Intermediate", ["shore", "reef fish", "macro"], []),
        ("Tutuba Passage", "Drift", "Advanced", ["current", "reef fish", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Barrier Reef Efate", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("Tanna Volcano Shelf", "Shore", "Intermediate", ["unique volcanic reef", "fish"], []),
        ("Aore Straits", "Drift", "Intermediate", ["current", "reef fish", "macro"], []),
    ],

    # ── Galapagos / Central America ────────────────────────────────────────
    "galapagos": [
        ("Mosquera Islet", "Reef", "Beginner", ["sea lions", "reef fish", "shallow", "penguins"], ["big-animals", "beginner-friendly"]),
        ("Gardner Bay", "Reef", "Intermediate", ["sea lions", "turtles", "reef fish"], ["big-animals"]),
        ("Champion Island", "Reef", "Intermediate", ["sea lions", "sharks", "reef fish"], ["big-animals"]),
        ("Española Reef", "Reef", "Intermediate", ["marine iguanas", "sea lions", "reef fish"], ["big-animals"]),
    ],
    "sea-of-cortez": [
        ("Baja Seamounts", "Reef", "Advanced", ["hammerheads", "pelagic", "remote"], ["big-animals", "advanced-challenges"]),
        ("Salvatierra Wreck", "Wreck", "Intermediate", ["ferry wreck", "reef fish", "sea lions"], ["wreck-capitals", "big-animals"]),
        ("Las Animas", "Reef", "Advanced", ["hammerheads", "sea lions", "current"], ["big-animals", "advanced-challenges"]),
        ("San Benedicto Socorro Extra", "Reef", "Advanced", ["humpback whales", "giant mantas", "dolphins"], ["big-animals", "liveaboard", "advanced-challenges"]),
    ],
    "cocos-island": [
        ("Dos Amigos Pequeno", "Reef", "Advanced", ["shark aggregation", "schooling fish", "current"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Punta Maria", "Reef", "Advanced", ["bulls sharks", "hammerheads", "schooling fish"], ["big-animals", "liveaboard"]),
    ],

    # ── Caribbean ─────────────────────────────────────────────────────────
    "florida-keys": [
        ("Sombrero Key", "Reef", "Beginner", ["lighthouse reef", "reef fish", "coral"], ["beginner-friendly"]),
        ("Crocker Reef", "Reef", "Beginner", ["reef", "reef fish", "coral"], ["beginner-friendly"]),
        ("Hen and Chickens Reef", "Reef", "Beginner", ["reef", "tropical fish", "coral"], ["beginner-friendly"]),
        ("Carysfort Reef", "Reef", "Intermediate", ["outer reef", "reef fish", "coral"], []),
        ("French Reef", "Reef", "Intermediate", ["caves", "swimthroughs", "reef fish"], ["caves-cenotes"]),
        ("Sand Island", "Reef", "Beginner", ["sandy bottom", "reef fish", "snorkel area"], ["beginner-friendly"]),
    ],
    "cayman-islands": [
        ("Don Foster's Reef", "Shore", "Beginner", ["shore", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Cali Wreck", "Wreck", "Beginner", ["old sailing ship", "shallow", "reef fish"], ["wreck-capitals", "beginner-friendly"]),
        ("Rock Reef", "Reef", "Beginner", ["reef fish", "coral", "calm"], ["beginner-friendly"]),
        ("Turtle Farm Reef", "Shore", "Beginner", ["shore", "turtles", "reef fish"], ["beginner-friendly"]),
    ],
    "bahamas": [
        ("Shark Junction Nassau", "Reef", "Intermediate", ["caribbean reef sharks", "fish diversity"], ["big-animals"]),
        ("James Bond Beach", "Shore", "Beginner", ["shore", "reef fish", "snorkel"], ["beginner-friendly"]),
        ("Andros Blue Holes", "Cave", "Intermediate", ["blue holes", "cavern", "crystal clear"], ["caves-cenotes"]),
        ("Exuma Cays", "Reef", "Intermediate", ["pristine reef", "iguana island nearby", "reef fish"], []),
        ("Cat Island Wall", "Wall", "Advanced", ["wall", "deep drop-off", "pelagic"], ["advanced-challenges"]),
    ],
    "honduras-bay-islands": [
        ("Texas", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("CoCo View Roatan", "Reef", "Beginner", ["resort reef", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Black Hills", "Wall", "Intermediate", ["wall", "fish diversity", "sponges"], []),
        ("Nick's Place Utila", "Reef", "Beginner", ["reef fish", "beginners", "coral"], ["beginner-friendly"]),
        ("Stingray Point Utila", "Shore", "Beginner", ["stingrays", "shore", "reef fish"], ["big-animals", "beginner-friendly"]),
        ("Airport Caves Utila", "Cave", "Intermediate", ["cavern", "swimthrough", "reef fish"], ["caves-cenotes"]),
    ],
    "bonaire": [
        ("Buddy's Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Calabas Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Nukove", "Shore", "Intermediate", ["wall", "coral", "shore"], []),
        ("Funchi", "Shore", "Beginner", ["shore", "reef fish", "beginners"], ["beginner-friendly"]),
    ],
    "belize": [
        ("Esmeralda Shoal", "Reef", "Intermediate", ["offshore shoal", "schooling fish", "sharks"], ["big-animals"]),
        ("Silk Cayes", "Reef", "Intermediate", ["remote caye", "reef fish", "clear water"], []),
        ("Caye Caulker Marine Reserve", "Shore", "Beginner", ["protected", "reef fish", "snorkel"], ["beginner-friendly"]),
    ],

    # ── Mediterranean ─────────────────────────────────────────────────────
    "greece-aegean": [
        ("Protaras Cyprus", "Shore", "Beginner", ["shore", "reef fish", "clear water"], ["beginner-friendly"]),
        ("Cape Greco Cyprus", "Reef", "Intermediate", ["reef fish", "caves", "clear water"], ["caves-cenotes"]),
        ("Zenobia Wreck Cyprus", "Wreck", "Intermediate", ["world's best wreck", "ferry", "coral growth", "fish"], ["wreck-capitals"]),
        ("Glaros Cyprus", "Reef", "Intermediate", ["reef", "reef fish", "clear water"], []),
        ("Ionnina Lake Greece", "Shore", "Intermediate", ["freshwater", "unique", "lake diving"], []),
    ],
    "italy-sicily": [
        ("Portofino Marine Reserve", "Reef", "Intermediate", ["marine reserve", "grouper", "reef fish"], []),
        ("Camogli", "Shore", "Intermediate", ["shore", "reef fish", "macro"], []),
        ("Baratti Gulf", "Reef", "Beginner", ["calm reef", "reef fish", "snorkel"], ["beginner-friendly"]),
        ("Marettimo Island", "Reef", "Advanced", ["remote", "pristine", "grouper", "reef fish"], ["advanced-challenges"]),
        ("Aeolian Islands Dive", "Reef", "Intermediate", ["volcanic", "reef fish", "unique"], []),
    ],
    "turkey-mediterranean": [
        ("Kaş Underwater Cave", "Cave", "Advanced", ["deep cave", "unique", "stalactites"], ["caves-cenotes", "advanced-challenges"]),
        ("Patara Reefs", "Reef", "Intermediate", ["reef fish", "macro", "current"], []),
        ("Antalya Bay", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("Gocek Bays", "Shore", "Beginner", ["anchor bays", "reef fish", "calm"], ["beginner-friendly"]),
        ("Fethiye Bay Wrecks", "Wreck", "Intermediate", ["wrecks", "reef fish", "history"], ["wreck-capitals"]),
    ],
    "spain-balearics": [
        ("Poseidon Reef Murcia", "Reef", "Intermediate", ["reef", "reef fish", "posidonia"], []),
        ("Las Hormigas", "Reef", "Advanced", ["current", "grouper", "barracuda"], ["advanced-challenges"]),
        ("Sa Dragonera Mallorca", "Reef", "Intermediate", ["reef fish", "marine reserve", "macro"], []),
        ("Cabrera National Park", "Reef", "Advanced", ["pristine national park", "grouper", "fish diversity"], ["advanced-challenges"]),
        ("Portlligat Costa Brava", "Shore", "Intermediate", ["shore", "reef fish", "posidonia"], []),
    ],

    # ── Red Sea ──────────────────────────────────────────────────────────
    "dahab": [
        ("Mashraba", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("The Mushroom", "Shore", "Beginner", ["mushroom coral formation", "reef fish"], ["beginner-friendly"]),
        ("Caves Dahab", "Cave", "Intermediate", ["cave system", "reef fish", "macro"], ["caves-cenotes"]),
        ("The Lighthouse South", "Shore", "Beginner", ["shore", "reef fish", "calm"], ["beginner-friendly"]),
        ("Abu Helal", "Shore", "Intermediate", ["reef", "reef fish", "current"], []),
    ],
    "aqaba-gulf": [
        ("First Gulf Aqaba", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Moon Valley Aqaba", "Shore", "Beginner", ["shore", "sandy", "reef fish"], ["beginner-friendly"]),
        ("Rainbow Reef Aqaba", "Shore", "Beginner", ["colorful reef", "reef fish", "shore"], ["beginner-friendly"]),
        ("Saudi Flagpole", "Shore", "Intermediate", ["reef", "reef fish", "coral"], []),
    ],

    # ── Maldives ──────────────────────────────────────────────────────────
    "maldives-liveaboard": [
        ("Veyvah Thila", "Reef", "Advanced", ["current", "schooling fish", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Mulaku Channel", "Drift", "Advanced", ["channel diving", "sharks", "current"], ["big-animals", "advanced-challenges"]),
        ("Felidhoo Atoll Wall", "Wall", "Advanced", ["wall", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Vaavu Atoll", "Reef", "Advanced", ["pristine atoll", "sharks", "reef fish"], ["big-animals", "liveaboard"]),
        ("Kolhufushi Caves", "Cave", "Intermediate", ["cavern system", "reef fish"], ["caves-cenotes"]),
    ],
    "seychelles": [
        ("Brisare Pinnacle", "Reef", "Intermediate", ["pinnacle", "fish diversity", "macro"], []),
        ("Sunset Reef Mahe", "Reef", "Intermediate", ["reef fish", "macro", "colorful coral"], []),
        ("Mahe Outer Reefs", "Reef", "Advanced", ["remote", "pelagic", "pristine"], ["big-animals", "advanced-challenges"]),
        ("Praslin Reefs", "Reef", "Intermediate", ["reef fish", "coral", "turtles"], []),
        ("Curieuse Island", "Shore", "Intermediate", ["turtles", "reef fish", "giant tortoises nearby"], ["big-animals"]),
    ],
    "sri-lanka": [
        ("Kalpitiya Whale Sharks", "Reef", "Intermediate", ["whale sharks", "seasonal", "reef fish"], ["big-animals"]),
        ("Pigeon Island Extension", "Reef", "Intermediate", ["reef", "blacktip sharks", "reef fish"], ["big-animals"]),
        ("Rumassala Reef", "Reef", "Beginner", ["beach reef", "reef fish", "calm"], ["beginner-friendly"]),
        ("Jungle Beach Unawatuna", "Shore", "Beginner", ["shore", "turtles", "reef fish"], ["beginner-friendly"]),
    ],

    # ── Pacific Islands ───────────────────────────────────────────────────
    "papua-new-guinea": [
        ("Planet Rock Extension", "Reef", "Advanced", ["aggregation of pelagics", "sharks", "current"], ["big-animals", "advanced-challenges"]),
        ("Banana Bommie", "Reef", "Intermediate", ["coral bommie", "fish diversity"], []),
        ("Kimbe Bay Wall", "Wall", "Intermediate", ["wall", "coral", "fish"], []),
        ("Cape Vogel", "Reef", "Intermediate", ["remote", "reef fish", "pristine"], []),
        ("MV Victory Wreck", "Wreck", "Intermediate", ["WWII transport wreck", "reef fish"], ["wreck-capitals"]),
        ("Samarai Island", "Reef", "Intermediate", ["reef fish", "historic island", "coral"], []),
    ],
    "solomon-islands": [
        ("Sandfly Passage", "Drift", "Intermediate", ["channel", "current", "reef fish"], []),
        ("Tulagi Harbour Wrecks", "Wreck", "Intermediate", ["multiple WWII wrecks", "harbor history"], ["wreck-capitals"]),
        ("Munda Barrier Reef", "Reef", "Intermediate", ["reef fish", "coral", "pristine"], []),
        ("Gizo Wrecks", "Wreck", "Intermediate", ["WWII wrecks", "reef fish"], ["wreck-capitals"]),
    ],
    "tonga": [
        ("'Eua Island Walls", "Wall", "Advanced", ["sheer wall", "humpback whales", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Ha'atafu Beach Reef", "Shore", "Beginner", ["shore", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Fafa Island Reef", "Reef", "Beginner", ["reef fish", "coral", "calm"], ["beginner-friendly"]),
        ("Pangaimotu Reef", "Shore", "Beginner", ["shore", "reef fish", "turtles"], ["beginner-friendly"]),
    ],
    "cook-islands-samoa": [
        ("Muri Lagoon Night", "Shore", "Beginner", ["night diving", "reef fish", "coral"], ["beginner-friendly"]),
        ("Avaavaroa Passage", "Drift", "Intermediate", ["current", "reef fish", "sharks"], ["big-animals"]),
        ("Puna Roa", "Reef", "Intermediate", ["reef", "fish diversity"], []),
        ("Samoa Palolo Deep", "Reef", "Intermediate", ["reef fish", "turtles", "protected"], []),
    ],
    "niue": [
        ("Matapa Chasm", "Cave", "Intermediate", ["cavern", "sea snakes", "unique"], ["caves-cenotes"]),
        ("Keyhole Cave", "Cave", "Beginner", ["unique cavern", "clear water", "sea snakes"], ["caves-cenotes", "beginner-friendly"]),
        ("Grotto Niue", "Cave", "Beginner", ["natural pool", "cave entry", "fish"], ["caves-cenotes", "beginner-friendly"]),
    ],

    # ── Micronesia ─────────────────────────────────────────────────────────
    "guam-northern-marianas": [
        ("Tokai Maru Wreck", "Wreck", "Intermediate", ["Japanese freighter", "reef fish", "deep"], ["wreck-capitals"]),
        ("American Tanker Wreck", "Wreck", "Intermediate", ["WWII tanker", "reef fish", "coral"], ["wreck-capitals"]),
        ("Hap's Reef", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("Finger Reef", "Reef", "Beginner", ["reef fish", "coral", "calm"], ["beginner-friendly"]),
        ("Outer Apra Harbor", "Reef", "Intermediate", ["reef fish", "WWII wrecks nearby", "coral"], []),
    ],
    "marshall-islands": [
        ("Kwajalein Wrecks", "Wreck", "Advanced", ["WWII wrecks", "deep", "history"], ["wreck-capitals", "advanced-challenges"]),
        ("Bikini Atoll", "Wreck", "Advanced", ["nuclear test site", "WWII fleet wrecks", "remote", "history"], ["wreck-capitals", "liveaboard", "advanced-challenges"]),
        ("Bikini Atoll USS Saratoga", "Wreck", "Advanced", ["aircraft carrier wreck", "deep", "unique"], ["wreck-capitals", "liveaboard", "advanced-challenges"]),
        ("Bikini Atoll Nagato", "Wreck", "Advanced", ["Japanese battleship", "deep", "history"], ["wreck-capitals", "liveaboard", "advanced-challenges"]),
        ("Rongerik Atoll", "Reef", "Advanced", ["remote atoll", "pristine", "sharks"], ["big-animals", "liveaboard"]),
    ],

    # ── Seychelles / Indian Ocean ────────────────────────────────────────
    "mauritius-reunion": [
        ("Cathedral Cave Reunion", "Cave", "Intermediate", ["lava tube", "unique", "reef fish"], ["caves-cenotes"]),
        ("Le Tombant de La Plaine Reunion", "Wall", "Advanced", ["wall", "pelagic", "current"], ["advanced-challenges"]),
        ("Passe de Bel Ombre", "Reef", "Intermediate", ["channel", "reef fish", "sharks"], ["big-animals"]),
        ("Flat Island Reef Mauritius", "Reef", "Intermediate", ["remote reef", "turtles", "reef fish"], []),
    ],

    # ── Andaman ────────────────────────────────────────────────────────────
    "andaman-nicobar": [
        ("Pilot Reef", "Reef", "Advanced", ["current", "sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Havelock Lighthouse", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("Radhanagar Beach Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Cinque Island South", "Reef", "Intermediate", ["pristine", "reef fish", "clear water"], []),
        ("Roper Reef", "Reef", "Advanced", ["remote", "sharks", "pristine"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Passage Island", "Reef", "Intermediate", ["reef fish", "current", "sharks"], ["big-animals"]),
    ],
}

# Second batch — filling thin regions to reach ~2,000 total
EXTRA_SITES_E2: dict[str, list] = {
    "ambon": [
        ("Laha Muck", "Shore", "Beginner", ["muck", "frogfish", "macro"], ["macro-muck", "beginner-friendly"]),
        ("Pintu Kota", "Cave", "Intermediate", ["cave entrance", "reef fish"], ["caves-cenotes"]),
        ("Batu Capeu", "Reef", "Intermediate", ["reef fish", "soft coral", "macro"], []),
    ],
    "flores-sea-indonesia": [
        ("Warloka Village", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("Sebayur Island", "Reef", "Intermediate", ["reef fish", "macro", "turtles"], []),
        ("Batu Bolong Flores", "Reef", "Advanced", ["current", "schooling fish"], ["advanced-challenges"]),
        ("Kanawa Island", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
    ],
    "tubbataha-cagayancillo": [
        ("Cagayancillo North", "Reef", "Advanced", ["pristine", "remote", "reef fish"], ["liveaboard", "advanced-challenges"]),
        ("Basterra East", "Reef", "Advanced", ["sharks", "pelagic", "remote"], ["big-animals", "liveaboard"]),
        ("South Tubbataha Atoll", "Reef", "Advanced", ["pristine atoll wall", "sharks"], ["big-animals", "liveaboard"]),
    ],
    "leyte-ormoc": [
        ("Ormoc Channel", "Drift", "Advanced", ["current", "pelagic", "tuna"], ["advanced-challenges"]),
        ("Ponson Island", "Reef", "Intermediate", ["reef fish", "macro", "remote"], []),
        ("Limasawa Island", "Reef", "Intermediate", ["historic site", "reef fish", "coral"], []),
    ],
    "sarawak-borneo": [
        ("Tanjung Datu", "Reef", "Advanced", ["remote", "pristine", "reef fish"], ["advanced-challenges"]),
        ("Pulau Talang-Talang Kecil", "Shore", "Beginner", ["turtle nesting", "reef fish"], ["big-animals", "beginner-friendly"]),
        ("Niah Caves Coast", "Shore", "Beginner", ["macro", "shore", "reef fish"], ["beginner-friendly"]),
        ("Similajau Coast", "Shore", "Intermediate", ["dolphins", "reef fish", "remote"], ["big-animals"]),
    ],
    "myanmar-mergui": [
        ("Burma Banks Shark Reef", "Reef", "Advanced", ["nurse sharks", "whale sharks", "remote"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Black Rock Myanmar", "Reef", "Advanced", ["hammerheads", "current", "remote"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Shark Cave Myanmar", "Cave", "Intermediate", ["nurse sharks", "reef fish"], ["caves-cenotes", "big-animals"]),
    ],
    "cambodia-koh-rong": [
        ("Condor Reef", "Reef", "Advanced", ["remote", "reef fish", "whale sharks seasonal"], ["big-animals", "liveaboard"]),
        ("Tang Krasang", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("Koh Tang Island", "Reef", "Intermediate", ["remote island", "reef fish", "coral"], []),
        ("Breakers Reef", "Reef", "Intermediate", ["reef", "fish diversity"], []),
    ],
    "vietnam-nha-trang-phu-quoc": [
        ("Hon Yen Island", "Reef", "Intermediate", ["reef", "fish diversity", "coral"], []),
        ("Bai Huong", "Shore", "Beginner", ["shore", "reef fish", "calm"], ["beginner-friendly"]),
        ("Nam Yết Reef", "Reef", "Advanced", ["remote Spratly reef", "pristine", "sharks"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Con Dao Islands", "Reef", "Intermediate", ["national park", "reef fish", "turtles"], ["big-animals"]),
    ],
    "indonesia-east-java": [
        ("Karimunjawa", "Reef", "Intermediate", ["reef fish", "coral", "clear water"], []),
        ("Nongsa Bintan", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
    ],
    "pohnpei-kosrae": [
        ("Palikir Channel", "Drift", "Advanced", ["current", "sharks", "fish"], ["big-animals", "advanced-challenges"]),
        ("Lenger Island", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("Kosrae Airport Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
    ],
    "sinai-north-red-sea": [
        ("Ras Nasrani", "Reef", "Intermediate", ["reef fish", "current", "turtles"], []),
        ("Ras Umm Sid North", "Reef", "Intermediate", ["coral pillars", "reef fish"], []),
        ("Pinky's Wall Sharm", "Wall", "Intermediate", ["wall", "soft coral", "fish"], []),
    ],
    "lakshadweep-india": [
        ("Pitti Island", "Reef", "Advanced", ["remote", "pristine", "pelagic"], ["liveaboard", "advanced-challenges"]),
        ("Cheriyam Island", "Reef", "Intermediate", ["atoll", "reef fish", "turtles"], []),
        ("Bitra Atoll", "Reef", "Advanced", ["remote", "pristine", "sharks"], ["big-animals", "liveaboard"]),
    ],
    "oman-uae": [
        ("Quoin Island", "Reef", "Advanced", ["remote", "hammerheads", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Musandam Fjords", "Reef", "Intermediate", ["fjord diving", "reef fish", "dolphins"], ["big-animals"]),
        ("Fahal Island", "Reef", "Intermediate", ["coral", "reef fish", "clear water"], []),
    ],
    "djibouti": [
        ("Arta Bay", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Ras Siyyan", "Reef", "Advanced", ["remote", "whale sharks", "hammerheads"], ["big-animals", "advanced-challenges"]),
    ],
    "comoros-mayotte": [
        ("Passe en S", "Drift", "Intermediate", ["channel", "reef fish", "sharks"], ["big-animals"]),
        ("Jardin de Corail", "Reef", "Beginner", ["coral garden", "reef fish", "turtles"], ["beginner-friendly"]),
    ],
    "coral-sea-outer": [
        ("Raine Island", "Reef", "Advanced", ["remote", "turtles nesting", "sharks"], ["big-animals", "liveaboard"]),
        ("Lihou Reef", "Reef", "Advanced", ["remote atoll", "pristine", "pelagic"], ["big-animals", "liveaboard"]),
        ("Marion Reef", "Reef", "Advanced", ["remote", "sharks", "pelagic"], ["big-animals", "liveaboard"]),
        ("Frederick Reef", "Reef", "Advanced", ["remote", "pristine", "sharks"], ["big-animals", "liveaboard"]),
    ],
    "turks-caicos-dominican": [
        ("Providenciales Coral Gardens", "Reef", "Beginner", ["coral", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Smith's Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Northwest Point Wall", "Wall", "Advanced", ["sheer wall", "pelagic", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Pine Cay", "Reef", "Intermediate", ["reef", "reef fish", "clear water"], []),
    ],
    "virgin-islands-usvi-bvi": [
        ("Coral Bay", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("Trunk Bay Reef USVI", "Shore", "Beginner", ["national park snorkel", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Cow and Calf", "Reef", "Intermediate", ["reef fish", "turtles", "barracuda"], []),
    ],
    "curacao-aruba": [
        ("Superior Producer Wreck Curaçao", "Wreck", "Intermediate", ["wreck", "reef fish", "sponges"], ["wreck-capitals"]),
        ("Mushroom Forest Extension", "Reef", "Intermediate", ["coral formations", "reef fish"], []),
        ("Baby Beach Aruba", "Shore", "Beginner", ["calm lagoon", "reef fish", "snorkel"], ["beginner-friendly"]),
    ],
    "croatia-adriatic": [
        ("Mljet National Park", "Reef", "Intermediate", ["marine park", "reef fish", "posidonia"], []),
        ("Hvar Island Wrecks", "Wreck", "Intermediate", ["wrecks", "reef fish", "history"], ["wreck-capitals"]),
        ("Brac Island Caves", "Cave", "Intermediate", ["caves", "reef fish", "macro"], ["caves-cenotes"]),
        ("Lastovo Island", "Reef", "Advanced", ["remote", "grouper", "pristine"], ["advanced-challenges"]),
    ],
    "canary-islands": [
        ("Fuerteventura Reefs", "Reef", "Intermediate", ["reef fish", "angel sharks", "macro"], ["big-animals"]),
        ("La Graciosa", "Shore", "Beginner", ["small island", "reef fish", "calm"], ["beginner-friendly"]),
        ("Lanzarote Caves", "Cave", "Intermediate", ["volcanic caves", "reef fish", "unique"], ["caves-cenotes"]),
    ],
    "azores-madeira": [
        ("Madeira Blue Sharks", "Reef", "Advanced", ["blue sharks", "open ocean", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Madeira Caves", "Cave", "Intermediate", ["volcanic caves", "reef fish"], ["caves-cenotes"]),
        ("Sao Miguel Fumaroles", "Reef", "Intermediate", ["hydrothermal", "unique", "reef fish"], []),
        ("Faial Caldeira", "Reef", "Intermediate", ["caldera walls", "reef fish", "unique"], []),
    ],
    "cocos-island": [
        ("Chatham Bay Cocos", "Reef", "Advanced", ["schooling fish", "sharks", "current"], ["big-animals", "liveaboard"]),
        ("Bajo Alcyone West", "Reef", "Advanced", ["whale sharks", "hammerheads", "current"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Roca Sucio", "Reef", "Advanced", ["silky sharks", "schooling fish"], ["big-animals", "liveaboard"]),
    ],
    "socorro-revillagigedo": [
        ("Roca Partida South", "Reef", "Advanced", ["hammerheads", "pelagic", "current"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("San Benedicto North", "Reef", "Advanced", ["giant mantas", "whale sharks", "dolphins"], ["big-animals", "liveaboard"]),
        ("Clarion Island", "Reef", "Advanced", ["remote pristine", "endemic species", "pelagic"], ["big-animals", "liveaboard", "advanced-challenges"]),
    ],
    "panama-colombia-pacific": [
        ("Coiba North Wall", "Wall", "Advanced", ["wall", "sharks", "pelagic"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Isla de Cocos Extension", "Reef", "Advanced", ["remote", "sharks", "pelagic"], ["big-animals", "liveaboard"]),
        ("Bahia Malaga", "Reef", "Intermediate", ["humpback whales", "reef fish", "remote"], ["big-animals"]),
    ],
    "colombian-caribbean": [
        ("Malpelo Extension", "Reef", "Advanced", ["hammerheads", "silky sharks", "whale sharks"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Gorgona Island", "Reef", "Advanced", ["humpback whales", "sharks", "national park"], ["big-animals", "advanced-challenges"]),
        ("Uramba Bahia Malaga NP", "Reef", "Intermediate", ["humpback whales", "reef fish", "protected"], ["big-animals"]),
    ],
    "ecuador-peru-pacific": [
        ("Cabo Manglares", "Reef", "Intermediate", ["mangrove coast", "reef fish", "remote"], []),
        ("Tumbes Coast", "Shore", "Intermediate", ["shore", "reef fish", "macro"], []),
        ("Punta Negra", "Shore", "Intermediate", ["cold upwelling", "sea lions", "fish density"], ["big-animals", "cold-water"]),
    ],
    "costa-rica-caribbean": [
        ("Limon Reefs", "Reef", "Beginner", ["reef fish", "turtles", "coral"], ["beginner-friendly"]),
        ("Punta Uva", "Shore", "Beginner", ["shore", "reef fish", "calm"], ["beginner-friendly"]),
        ("Manzanillo Extension", "Reef", "Intermediate", ["reef fish", "turtles", "dolphins"], ["big-animals"]),
    ],
    "mexico-gulf-veracruz": [
        ("Los Tuneles", "Reef", "Intermediate", ["reef", "fish diversity", "reef fish"], []),
        ("Isla de Enmedio", "Reef", "Intermediate", ["reef", "reef fish", "turtles"], []),
        ("Banco Negros", "Reef", "Advanced", ["remote bank", "pelagic", "fish density"], ["advanced-challenges"]),
    ],
    "galapagos-mainland-ecuador": [
        ("Machalilla Outer", "Reef", "Advanced", ["whale sharks", "hammerheads", "remote"], ["big-animals", "advanced-challenges"]),
        ("Salango Bay", "Reef", "Intermediate", ["reef fish", "humpbacks seasonal", "macro"], ["big-animals"]),
        ("Tortuga Island", "Reef", "Intermediate", ["reef fish", "sea turtles", "coral"], ["big-animals"]),
        ("Frailes Point", "Reef", "Intermediate", ["reef fish", "pelagic", "dolphins"], ["big-animals"]),
    ],
    "patagonia-chile": [
        ("Valparaiso Wrecks", "Wreck", "Intermediate", ["wrecks", "cold water", "reef fish"], ["wreck-capitals", "cold-water"]),
        ("Isla Mocha", "Reef", "Advanced", ["remote", "sperm whales", "cold water"], ["big-animals", "cold-water", "advanced-challenges"]),
    ],
    "iceland-greenland": [
        ("Thingvellir National Park", "Cave", "Intermediate", ["tectonic fissures", "freshwater", "clear"], ["caves-cenotes", "cold-water"]),
        ("Reykjanes Peninsula", "Shore", "Advanced", ["geothermal vents", "cold water", "unique"], ["cold-water", "advanced-challenges"]),
        ("Greenland Icebergs", "Reef", "Advanced", ["iceberg diving", "extreme cold", "unique"], ["cold-water", "advanced-challenges"]),
    ],
    "south-africa-cold-atlantic": [
        ("South Georgia King Penguins", "Reef", "Advanced", ["king penguins", "leopard seals", "remote"], ["big-animals", "cold-water", "liveaboard"]),
        ("Elephant Island", "Reef", "Advanced", ["Shackleton history", "elephant seals", "remote"], ["big-animals", "cold-water", "liveaboard"]),
        ("Weddell Sea", "Shore", "Advanced", ["ice diving", "extreme cold", "weddell seals"], ["cold-water", "liveaboard", "advanced-challenges"]),
    ],
    "taiwan": [
        ("Green Island Marine Park", "Reef", "Intermediate", ["coral gardens", "reef fish", "clear"], []),
        ("Wanlitung Reef", "Reef", "Beginner", ["reef fish", "coral", "calm"], ["beginner-friendly"]),
    ],
    "korea-china-seas": [
        ("Jeju Haenyeo Dive Sites", "Shore", "Intermediate", ["traditional diving culture", "abalone", "unique"], []),
        ("Namhae Coast", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("Heuksando Islands", "Reef", "Intermediate", ["remote", "reef fish", "cold water"], ["cold-water"]),
        ("Geomundo Island", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("Ulleungdo Island", "Reef", "Advanced", ["remote volcanic", "reef fish", "cold water"], ["cold-water", "advanced-challenges"]),
    ],
    "hong-kong-guangdong": [
        ("Tung Lung Chau", "Shore", "Intermediate", ["shore", "reef fish", "unique rock carvings nearby"], []),
        ("Basalt Island HK", "Reef", "Intermediate", ["hexagonal columns", "reef fish", "unique"], []),
        ("East Dam Sai Kung", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
    ],
    "ogasawara-islands": [
        ("Ani-jima Channel", "Drift", "Advanced", ["current", "schooling fish", "dolphins"], ["big-animals", "advanced-challenges"]),
        ("Nishi-jima", "Reef", "Intermediate", ["reef fish", "endemic species"], []),
        ("Whale Shark Season Chichi", "Reef", "Intermediate", ["whale sharks seasonal", "dolphins", "pelagic"], ["big-animals"]),
    ],
    "st-helena-ascension": [
        ("Heart Shaped Waterfall", "Shore", "Beginner", ["shore", "reef fish", "unique landscape"], ["beginner-friendly"]),
        ("James Bay Reef", "Shore", "Intermediate", ["reef fish", "endemic species", "clear water"], []),
        ("Prosperous Bay", "Shore", "Beginner", ["calm bay", "reef fish", "unique"], ["beginner-friendly"]),
        ("Ascension North Wall", "Wall", "Advanced", ["wall", "pelagic", "endemic species"], ["advanced-challenges"]),
        ("Green Mountain Reef", "Reef", "Intermediate", ["reef", "endemic fish", "unique island"], []),
        ("Napoleon Boonekamp", "Shore", "Intermediate", ["history", "reef fish", "macro"], []),
    ],
    "mozambique-north": [
        ("Ilha do Ibo Reef", "Reef", "Beginner", ["historic island", "reef fish", "calm"], ["beginner-friendly"]),
        ("Matemo Island", "Reef", "Intermediate", ["reef fish", "mantas", "pristine"], ["big-animals"]),
        ("Macaloe Point", "Reef", "Advanced", ["sharks", "pelagic", "current"], ["big-animals", "advanced-challenges"]),
    ],
    "new-zealand": [
        ("Poor Knights Extension", "Cave", "Intermediate", ["sea caves", "archways", "unique fauna"], ["caves-cenotes", "cold-water"]),
        ("Tauranga Bay", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["cold-water", "beginner-friendly"]),
        ("White Island Dive", "Reef", "Advanced", ["active volcano", "extreme pH", "unique"], ["advanced-challenges"]),
    ],
    "marshall-islands": [
        ("Bikini Atoll USS Arkansas", "Wreck", "Advanced", ["WWII battleship", "deep", "remote"], ["wreck-capitals", "liveaboard", "advanced-challenges"]),
    ],
}

EXTRA_SITES_E3: dict[str, list] = {
    # South Africa (58 → ~75)
    "south-africa-eastern-cape": [
        ("Durban Blue Lagoon", "Shore", "Beginner", ["shore", "reef fish", "beginner friendly"], ["beginner-friendly"]),
        ("Ansteys Beach", "Shore", "Beginner", ["shore", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Deep Blue", "Reef", "Advanced", ["deep reef", "ragged tooth sharks", "fish"], ["big-animals", "advanced-challenges"]),
    ],
    "south-africa-western-cape": [
        ("Ou Skip", "Wreck", "Intermediate", ["wreck", "cold water", "reef fish"], ["wreck-capitals", "cold-water"]),
        ("Camps Bay Reef", "Shore", "Intermediate", ["cold water", "reef fish", "macro"], ["cold-water"]),
        ("Hout Bay Seal Colony", "Shore", "Intermediate", ["cape fur seals", "cold water", "playful"], ["big-animals", "cold-water"]),
        ("Kommetjie Pinnacles", "Reef", "Intermediate", ["pinnacles", "cold water", "fish density"], ["cold-water"]),
    ],
    "st-helena-ascension": [
        ("High Knoll Fort Reef", "Shore", "Beginner", ["history", "reef fish", "shore"], ["beginner-friendly"]),
        ("Jamestown Wharf", "Shore", "Beginner", ["pier", "reef fish", "macro"], ["beginner-friendly"]),
    ],
    "mozambique-north": [
        ("Medjumbe Outer", "Reef", "Advanced", ["pelagic", "sharks", "remote"], ["big-animals", "advanced-challenges"]),
        ("Ruvuma Estuary", "Shore", "Intermediate", ["estuary", "reef fish", "unique habitat"], []),
    ],

    # South America (68 → ~85)
    "brazil-northeast": [
        ("Rio de Janeiro Reefs", "Reef", "Intermediate", ["reef fish", "macro", "unique urban diving"], []),
        ("Tijuca Banks", "Reef", "Advanced", ["offshore banks", "pelagic", "fish density"], ["advanced-challenges"]),
    ],
    "colombia-venezuela-caribbean": [
        ("Archipiélago de los Testigos", "Reef", "Advanced", ["remote Venezuelan islands", "pristine", "sharks"], ["big-animals", "liveaboard"]),
        ("Isla La Tortuga Venezuela", "Reef", "Intermediate", ["turtles", "reef fish", "pristine"], ["big-animals"]),
        ("Morrocoy Cayo Sombrero", "Reef", "Beginner", ["calm reef", "reef fish", "snorkel"], ["beginner-friendly"]),
    ],
    "patagonia-chile": [
        ("Chiloé Kelp Forest", "Shore", "Advanced", ["kelp forest", "cold water", "unique"], ["cold-water", "advanced-challenges"]),
        ("Carretera Austral", "Shore", "Intermediate", ["freshwater fjord", "cold", "unique"], ["cold-water"]),
    ],

    # East Africa (72 → ~88)
    "kenya-zanzibar": [
        ("Pungume Island", "Reef", "Intermediate", ["reef fish", "coral", "remote"], []),
        ("Kwale Island", "Reef", "Beginner", ["reef fish", "snorkel", "calm"], ["beginner-friendly"]),
    ],
    "djibouti": [
        ("Godoria Bay", "Reef", "Beginner", ["shore", "reef fish", "calm"], ["beginner-friendly"]),
        ("Moucha House Reef", "Shore", "Beginner", ["housereef", "reef fish", "macro"], ["beginner-friendly"]),
        ("Ras Ali Point", "Reef", "Intermediate", ["reef", "reef fish", "current"], []),
    ],
    "madagascar": [
        ("Nosy Komba", "Reef", "Beginner", ["reef fish", "turtles", "coral"], ["beginner-friendly"]),
        ("Sakatia Island", "Reef", "Intermediate", ["reef", "fish diversity", "whale sharks seasonal"], ["big-animals"]),
        ("Nosy Tanikely", "Reef", "Beginner", ["marine reserve", "turtles", "reef fish"], ["beginner-friendly"]),
    ],

    # Cold Water (94 → ~105)
    "iceland-greenland": [
        ("Þingvallavatn Extension", "Cave", "Intermediate", ["fresh water fissure", "crystal clear", "cold"], ["caves-cenotes", "cold-water"]),
        ("Geldingadalir Coastal", "Shore", "Advanced", ["volcanic coastline", "cold", "unique"], ["cold-water", "advanced-challenges"]),
    ],
    "south-africa-cold-atlantic": [
        ("Bouvet Island", "Reef", "Advanced", ["remotest island on earth", "extreme cold", "unique"], ["cold-water", "liveaboard", "advanced-challenges"]),
        ("Peter I Island", "Reef", "Advanced", ["very remote", "leopard seals", "pristine"], ["big-animals", "cold-water", "liveaboard", "advanced-challenges"]),
    ],
    "northeast-usa": [
        ("Isles of Shoals", "Reef", "Intermediate", ["reef fish", "lobster", "cold Atlantic"], ["cold-water"]),
        ("Provincetown Pier", "Shore", "Beginner", ["pier", "cold water", "macro"], ["cold-water", "beginner-friendly"]),
        ("Cape Ann", "Shore", "Intermediate", ["cold water", "reef fish", "lobster"], ["cold-water"]),
    ],

    # Japan (87 → ~95)
    "ogasawara-islands": [
        ("Night Dive Bonin", "Shore", "Intermediate", ["night diving", "macro", "reef fish"], ["macro-muck"]),
    ],
    "izu-peninsula-japan": [
        ("Mera", "Shore", "Intermediate", ["macro", "seahorse", "reef fish"], ["macro-muck"]),
        ("Toi", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
    ],
    "korea-china-seas": [
        ("Dadohae Maritime NP", "Reef", "Intermediate", ["marine park", "reef fish", "islands"], []),
    ],

    # Socorro/Central Am (7 → 10+)
    "socorro-revillagigedo": [
        ("Roca Partida Night", "Reef", "Advanced", ["silky sharks night", "bioluminescence", "unique"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("San Benedicto Manta Point", "Reef", "Advanced", ["giant mantas", "cleaning station", "unique"], ["big-animals", "liveaboard"]),
    ],
    "panama-colombia-pacific": [
        ("Golfo de Tribugá", "Reef", "Intermediate", ["remote bay", "humpback whales", "reef fish"], ["big-animals"]),
        ("Ensenada de Utría", "Reef", "Intermediate", ["national park", "humpback whales", "reef fish"], ["big-animals"]),
        ("Gorgona North Wall", "Wall", "Advanced", ["wall", "sharks", "remote"], ["big-animals", "advanced-challenges"]),
    ],

    # Micronesia (105 → ~110)
    "guam-northern-marianas": [
        ("Blue Hole Guam", "Cave", "Intermediate", ["cavern", "swimthrough", "reef fish"], ["caves-cenotes"]),
        ("Fish Eye Marine Park", "Shore", "Beginner", ["protected", "reef fish", "underwater observatory"], ["beginner-friendly"]),
    ],
    "pohnpei-kosrae": [
        ("Nan Madol Night", "Reef", "Intermediate", ["night diving", "reef fish", "unique history"], []),
        ("Mwand Pass", "Drift", "Advanced", ["channel", "current", "sharks"], ["big-animals", "advanced-challenges"]),
    ],

    # Red Sea (86 → ~93)
    "sinai-north-red-sea": [
        ("Turtle Bay Tiran", "Reef", "Beginner", ["turtles", "reef fish", "calm"], ["beginner-friendly"]),
        ("Lagoon Reef", "Reef", "Beginner", ["calm lagoon", "reef fish", "coral"], ["beginner-friendly"]),
    ],
    "hurghada": [
        ("Abu Ramada Mushroom", "Reef", "Intermediate", ["mushroom coral", "reef fish"], []),
        ("Gota Erg Abu Ramada", "Reef", "Intermediate", ["reef fish", "soft coral"], []),
    ],

    # Australia (97 → ~105)
    "coral-sea-outer": [
        ("Holmes Reef", "Reef", "Advanced", ["remote", "pristine", "sharks", "pelagic"], ["big-animals", "liveaboard"]),
        ("Cato Island", "Reef", "Advanced", ["remote", "wildlife", "pristine reef"], ["liveaboard"]),
        ("Coringa-Herald NR", "Reef", "Advanced", ["remote", "pristine", "pelagic"], ["liveaboard", "advanced-challenges"]),
    ],
    "new-zealand": [
        ("Cape Rodney-Okakari Point", "Shore", "Intermediate", ["marine reserve", "fish density", "snapper"], ["cold-water"]),
        ("Tawharanui Marine Park", "Shore", "Beginner", ["marine park", "reef fish", "cold water"], ["cold-water", "beginner-friendly"]),
    ],
}

EXTRA_SITES_E4: dict[str, list] = {
    # Push South Africa over 80
    "south-africa-eastern-cape": [
        ("Umkomaas Reef", "Reef", "Intermediate", ["reef fish", "turtles", "sharks"], ["big-animals"]),
        ("Warner Beach", "Shore", "Beginner", ["shore", "reef fish", "beginner"], ["beginner-friendly"]),
        ("Umtentweni Reef", "Reef", "Intermediate", ["reef fish", "soft coral"], []),
        ("Shelley Beach Inner Reef", "Shore", "Beginner", ["shore", "reef fish", "calm"], ["beginner-friendly"]),
    ],
    "south-africa-western-cape": [
        ("Whale Rock Kalk Bay", "Reef", "Intermediate", ["cold water", "reef fish", "kelp"], ["cold-water"]),
        ("The Arch Simonstown", "Reef", "Intermediate", ["arch", "cold water", "seals"], ["big-animals", "cold-water"]),
    ],

    # Push South America over 90
    "colombia-venezuela-caribbean": [
        ("Isla de Providencia Extension", "Reef", "Advanced", ["3rd largest barrier reef", "remote", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Golfo Morrosquillo", "Reef", "Beginner", ["calm gulf", "reef fish", "coral"], ["beginner-friendly"]),
        ("Playa Blanca Barú", "Shore", "Beginner", ["beach reef", "reef fish", "snorkel"], ["beginner-friendly"]),
    ],
    "brazil-northeast": [
        ("Fernando de Noronha Night", "Shore", "Intermediate", ["night diving", "reef fish", "bioluminescence"], []),
        ("Recife Port Wrecks", "Wreck", "Intermediate", ["multiple wrecks", "reef fish", "history"], ["wreck-capitals"]),
    ],

    # Push East Africa over 90
    "kenya-zanzibar": [
        ("Pemba South", "Reef", "Advanced", ["walls", "pelagic", "pristine"], ["big-animals", "advanced-challenges"]),
        ("Tumbatu Island", "Reef", "Intermediate", ["reef fish", "coral", "remote"], []),
        ("Jozani Forest Coast", "Shore", "Beginner", ["shore", "reef fish", "mangrove"], ["beginner-friendly"]),
    ],
    "oman-uae": [
        ("Dibba Reef", "Reef", "Intermediate", ["reef fish", "coral", "macro"], []),
        ("Al Ghariya Qatar", "Reef", "Beginner", ["reef fish", "macro", "calm waters"], ["beginner-friendly"]),
        ("Daymaniyat South", "Reef", "Intermediate", ["reef fish", "turtles", "coral"], []),
    ],

    # Push Malaysia over 95
    "tioman-east-coast-malaysia": [
        ("Pasir Tengkorak", "Shore", "Beginner", ["shore", "reef fish", "snorkel"], ["beginner-friendly"]),
        ("Tekek Beach Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Mentawak Rock", "Reef", "Advanced", ["current", "pelagic", "reef fish"], ["advanced-challenges"]),
    ],

    # Push Japan over 97
    "okinawa-japan": [
        ("Tokashiki Island", "Reef", "Intermediate", ["reef fish", "clear water", "macro"], []),
        ("Zamamijima", "Reef", "Intermediate", ["reef fish", "turtles", "dolphins"], ["big-animals"]),
    ],
    "izu-peninsula-japan": [
        ("Akao Reef", "Shore", "Intermediate", ["macro", "nudibranchs", "reef fish"], ["macro-muck"]),
    ],

    # Maldives (95 → 100)
    "maldives-north-male-atoll": [
        ("Madivaru Corner", "Reef", "Advanced", ["current", "sharks", "eagle rays"], ["big-animals", "advanced-challenges"]),
        ("Vadhoo Reef", "Reef", "Beginner", ["reef fish", "coral", "calm"], ["beginner-friendly"]),
        ("Girifushi Wreck", "Wreck", "Intermediate", ["sunken patrol boat", "reef fish"], ["wreck-capitals"]),
        ("Kuda Giri Wreck", "Wreck", "Beginner", ["shallow wreck", "reef fish", "coral"], ["wreck-capitals", "beginner-friendly"]),
    ],
    "maldives-ari-atoll": [
        ("Mahibadhoo Kandu", "Reef", "Advanced", ["current", "sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Thudufushi Caves", "Cave", "Intermediate", ["cavern", "reef fish", "macro"], ["caves-cenotes"]),
    ],

    # Red Sea (90 → 97)
    "red-sea-liveaboard": [
        ("Shaab Sharm", "Reef", "Intermediate", ["remote reef", "reef fish", "pristine"], ["liveaboard"]),
        ("Shaab Sataya Dolphins", "Reef", "Intermediate", ["spinner dolphins", "reef fish", "remote"], ["big-animals", "liveaboard"]),
    ],
    "hurghada": [
        ("Sharm El Naga", "Reef", "Beginner", ["protected bay", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Sha'ab Abu Gafan", "Reef", "Intermediate", ["reef", "fish diversity"], []),
        ("Gifton Reef Extension", "Reef", "Beginner", ["reef fish", "coral", "calm"], ["beginner-friendly"]),
    ],

    # Central America (97 → 103)
    "sea-of-cortez": [
        ("Los Islotes Extension", "Shore", "Beginner", ["sea lions", "reef fish", "playful"], ["big-animals", "beginner-friendly"]),
        ("San Juanico", "Reef", "Intermediate", ["whale sharks seasonal", "reef fish", "remote"], ["big-animals"]),
        ("Isla Espiritu Santo", "Reef", "Intermediate", ["sea lions", "reef fish", "snorkel"], ["big-animals"]),
    ],
}
