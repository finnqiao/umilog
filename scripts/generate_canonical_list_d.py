#!/usr/bin/env python3
"""
Part D — extra sites appended to existing regions, plus new stand-alone regions.
EXTRA_SITES: dict[region_id, list of raw site tuples/strings]
EXTRA_REGIONS: dict[group_id, list of region dicts]
"""

# Additional dive sites appended to existing regions
EXTRA_SITES: dict[str, list] = {

    "raja-ampat": [
        ("Wayag Lagoon", "Reef", "Intermediate", ["lagoon", "karst islands", "reef fish"], ["liveaboard"]),
        ("Pulau Mansuar", "Reef", "Beginner", ["reef fish", "coral garden"], ["beginner-friendly"]),
        ("Sawinggrai Reef", "Shore", "Beginner", ["shore", "coral", "macro"], ["beginner-friendly"]),
        ("Yenbuba Passage", "Drift", "Intermediate", ["current", "reef fish", "schooling fish"], []),
        ("Kri Eco Resort Housereef", "Shore", "Beginner", ["house reef", "coral", "fish"], ["beginner-friendly"]),
        ("Pianemo Lagoon", "Reef", "Intermediate", ["lagoon", "reef fish", "snorkel"], []),
        ("Bat Island", "Reef", "Beginner", ["bats", "reef fish", "unique"], []),
        ("Kabui Bay", "Shore", "Beginner", ["mangrove", "dugong", "macro"], ["big-animals", "beginner-friendly"]),
    ],

    "komodo-national-park": [
        ("Rinca Wall", "Wall", "Intermediate", ["wall", "soft coral", "fish"], []),
        ("Gili Lawa Laut", "Reef", "Advanced", ["current", "schooling fish", "pelagic"], ["advanced-challenges"]),
        ("Toro Wall", "Wall", "Intermediate", ["wall", "coral", "reef fish"], []),
        ("Pantai Merah South", "Reef", "Beginner", ["pink beach", "coral garden", "fish"], ["beginner-friendly"]),
    ],

    "bali-nusa-islands": [
        ("Padang Bai Blue Lagoon", "Reef", "Beginner", ["coral", "reef fish", "beginners"], ["beginner-friendly"]),
        ("Padang Bai White Sand", "Shore", "Beginner", ["shore", "macro", "turtles"], ["beginner-friendly"]),
        ("Temple Site Pemuteran", "Reef", "Beginner", ["biorock restoration", "coral garden", "fish"], ["beginner-friendly"]),
        ("Secret Point Menjangan", "Wall", "Intermediate", ["wall", "coral", "turtles"], []),
        ("Nusa Dua Reef", "Reef", "Beginner", ["calm water", "coral", "reef fish"], ["beginner-friendly"]),
        ("Padangbai Bay", "Shore", "Beginner", ["macro", "nudibranch", "cuttlefish"], ["macro-muck", "beginner-friendly"]),
    ],

    "lembeh-strait": [
        ("Aer Prang", "Shore", "Beginner", ["muck", "frogfish", "cuttlefish"], ["macro-muck"]),
        ("Police Pier Night", "Shore", "Beginner", ["night diving", "macro", "cuttlefish eggs"], ["macro-muck"]),
        ("Nudibranch City", "Shore", "Beginner", ["nudibranchs", "muck", "macro"], ["macro-muck"]),
        ("Sahaung", "Shore", "Beginner", ["muck", "seahorse", "ghostpipefish"], ["macro-muck"]),
        ("Pantarei", "Shore", "Beginner", ["muck", "macro", "night diving"], ["macro-muck"]),
        ("Goby a Shrimp", "Shore", "Beginner", ["goby and shrimp", "macro", "sandy"], ["macro-muck"]),
    ],

    "bunaken-sulawesi": [
        ("Alung Banua", "Wall", "Intermediate", ["wall", "fish diversity"], []),
        ("Siladen Wall", "Wall", "Intermediate", ["wall", "soft coral", "schooling fish"], []),
        ("Tengah Wall", "Wall", "Intermediate", ["wall", "current"], []),
        ("Muka Gepe", "Wall", "Intermediate", ["wall", "sharks", "current"], ["big-animals"]),
        ("Burak Wall", "Wall", "Beginner", ["wall", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Pangalisang", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
    ],

    "alor-strait": [
        ("Kal's Dream", "Reef", "Intermediate", ["reef", "fish diversity", "macro"], []),
        ("The Cathedral Alor", "Cave", "Intermediate", ["cavern", "light", "reef fish"], ["caves-cenotes"]),
        ("Magic Mountain Alor", "Reef", "Advanced", ["manta rays", "current", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Batu Tiga Alor", "Reef", "Advanced", ["current", "sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
    ],

    "banda-sea": [
        ("Ai Island", "Reef", "Advanced", ["remote", "pristine", "sharks", "pelagic"], ["big-animals", "liveaboard"]),
        ("Neira Wall", "Wall", "Intermediate", ["wall", "soft coral", "fish diversity"], []),
        ("Hatta Island", "Reef", "Advanced", ["remote", "sharks", "pristine"], ["big-animals", "liveaboard"]),
        ("Manuk Island Volcano", "Reef", "Advanced", ["volcanic island", "sea snakes", "unique"], ["advanced-challenges", "liveaboard"]),
    ],

    "gili-islands-lombok": [
        ("Gili Trawangan Coral", "Reef", "Beginner", ["coral restoration", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Gili Air Wall", "Wall", "Intermediate", ["wall", "reef fish", "current"], []),
        ("Gili Meno Halik", "Reef", "Beginner", ["turtles", "reef fish", "calm"], ["beginner-friendly"]),
        ("Sunset Reef Gili T", "Reef", "Beginner", ["coral", "reef fish", "sunset"], ["beginner-friendly"]),
        ("Biorock Gili Trawangan", "Shore", "Beginner", ["biorock", "restoration", "reef fish"], ["beginner-friendly"]),
        ("Gili Layar", "Reef", "Intermediate", ["remote", "reef fish", "macro"], []),
    ],

    "tubbataha-reefs": [
        ("Jessie Beazley South", "Reef", "Advanced", ["whale sharks", "remote", "pristine"], ["big-animals", "liveaboard"]),
        ("Black Rock Tubbataha", "Reef", "Advanced", ["schooling fish", "sharks", "pelagic"], ["big-animals", "advanced-challenges", "liveaboard"]),
        ("Washing Machine", "Drift", "Advanced", ["extreme current", "schooling fish", "adrenaline"], ["advanced-challenges", "liveaboard"]),
        ("NW Reef Tubbataha", "Wall", "Advanced", ["wall", "pelagic", "sharks"], ["big-animals", "liveaboard"]),
        ("Southwest Atoll", "Reef", "Advanced", ["remote", "pristine", "sharks"], ["big-animals", "liveaboard"]),
    ],

    "anilao-batangas": [
        ("Bethlehem", "Shore", "Intermediate", ["coral", "macro", "reef fish"], []),
        ("Secret Bay Anilao", "Shore", "Beginner", ["muck", "frogfish", "ghost pipefish"], ["macro-muck", "beginner-friendly"]),
        ("Mainit", "Reef", "Advanced", ["thermocline", "cold upwelling", "sharks"], ["advanced-challenges"]),
        ("Cathedral Rock Anilao", "Reef", "Intermediate", ["reef", "schooling fish", "soft coral"], []),
        ("Sombrero Island", "Reef", "Intermediate", ["reef", "turtles", "fish"], []),
        ("Twin Rocks Anilao", "Reef", "Intermediate", ["reef", "macro", "reef fish"], ["macro-muck"]),
        ("Mucky Pipeline", "Shore", "Beginner", ["muck", "macro", "unique critters"], ["macro-muck", "beginner-friendly"]),
        ("Ligpo Island", "Wall", "Intermediate", ["wall", "reef fish", "macro"], []),
    ],

    "malapascua": [
        ("Dona Marilyn Wreck", "Wreck", "Intermediate", ["ferry wreck", "reef fish", "coral growth"], ["wreck-capitals"]),
        ("Gato Island Cave", "Cave", "Intermediate", ["cavern", "sea snakes", "reef fish"], ["caves-cenotes"]),
        ("Monad Shoal Extension", "Reef", "Advanced", ["thresher sharks early morning", "deep platform"], ["big-animals", "advanced-challenges"]),
        ("Calanggaman Island", "Reef", "Intermediate", ["sandbar", "reef fish", "snorkel"], []),
        ("Lighthouse Malapascua", "Reef", "Intermediate", ["reef", "turtles", "fish"], []),
    ],

    "cebu-moalboal-mactan": [
        ("OTC Wreck Mactan", "Wreck", "Intermediate", ["wreck", "reef fish", "macro"], ["wreck-capitals"]),
        ("Kontiki Reef", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
        ("Alegre Reef", "Reef", "Beginner", ["reef fish", "coral"], ["beginner-friendly"]),
        ("Hilutungan Marine Sanctuary", "Reef", "Beginner", ["marine sanctuary", "turtles", "reef fish"], ["beginner-friendly"]),
        ("Marigondon Cave Mactan", "Cave", "Intermediate", ["freshwater cave", "reef fish"], ["caves-cenotes"]),
        ("Kawasan Falls Canyoneering", "Reef", "Beginner", ["freshwater", "unique", "swimming"], ["beginner-friendly"]),
    ],

    "bohol-panglao-balicasag": [
        ("Doljo Beach", "Shore", "Beginner", ["shore", "macro", "reef fish"], ["beginner-friendly"]),
        ("Napaling", "Drift", "Intermediate", ["drift", "fish", "current"], []),
        ("Arco Point", "Reef", "Intermediate", ["coral", "reef fish", "current"], []),
        ("Danao Beach", "Shore", "Beginner", ["shore", "macro", "coral"], ["beginner-friendly"]),
        ("Snake Island Bohol", "Reef", "Intermediate", ["sandbar", "reef fish"], []),
        ("Cervera Shoal", "Reef", "Advanced", ["hammerheads", "schooling fish", "current"], ["big-animals", "advanced-challenges"]),
    ],

    "puerto-galera": [
        ("The Canyons", "Wall", "Advanced", ["deep canyons", "current", "pelagic"], ["advanced-challenges"]),
        ("Hole in the Wall PG", "Cave", "Intermediate", ["swimthrough", "reef fish", "current"], ["caves-cenotes"]),
        ("Coral Garden PG", "Reef", "Beginner", ["coral", "reef fish", "macro"], ["beginner-friendly"]),
        ("Sinandigan Wall", "Wall", "Intermediate", ["wall", "soft coral", "fish"], []),
        ("Sabang Point", "Reef", "Advanced", ["current", "pelagic", "sharks"], ["big-animals", "advanced-challenges"]),
        ("La Laguna Beach", "Shore", "Beginner", ["shore", "macro", "reef fish"], ["beginner-friendly"]),
    ],

    "coron-busuanga": [
        ("Skeleton Wreck", "Wreck", "Intermediate", ["WWII wreck", "coral", "reef fish"], ["wreck-capitals"]),
        ("East Tangat Wreck", "Wreck", "Intermediate", ["WWII wreck", "deep", "coral"], ["wreck-capitals"]),
        ("Okikawa Maru", "Wreck", "Intermediate", ["large WWII tanker", "reef fish"], ["wreck-capitals"]),
        ("Lusong Coral Garden", "Reef", "Beginner", ["coral garden", "reef fish", "turtles"], ["beginner-friendly"]),
        ("CYC Beach Reef", "Shore", "Beginner", ["shore", "coral", "reef fish"], ["beginner-friendly"]),
        ("Barracuda Lake", "Reef", "Intermediate", ["thermocline lake", "barracuda", "unique"], []),
        ("Twin Lagoon", "Shore", "Beginner", ["lagoon", "snorkel", "unique access"], ["beginner-friendly"]),
        ("Siete Picados", "Reef", "Intermediate", ["seven peaks", "reef fish", "macro"], []),
    ],

    "dauin-apo-island": [
        ("Apo Island South Wall", "Wall", "Intermediate", ["wall", "reef fish", "turtles"], []),
        ("Apo Island Chapel", "Reef", "Intermediate", ["fish sanctuary", "schooling fish"], []),
        ("Muck Zone Dauin", "Shore", "Beginner", ["muck", "frogfish", "seahorse"], ["macro-muck", "beginner-friendly"]),
        ("Masaplod Norte", "Shore", "Beginner", ["muck", "macro", "critters"], ["macro-muck", "beginner-friendly"]),
        ("Basak Dauin", "Shore", "Intermediate", ["muck", "rare critters", "night diving"], ["macro-muck"]),
        ("Poblacion Dauin", "Shore", "Beginner", ["shore", "macro", "reef fish"], ["macro-muck", "beginner-friendly"]),
        ("Mainit Dauin", "Shore", "Intermediate", ["thermocline", "muck", "macro"], ["macro-muck"]),
    ],

    "sipadan-mabul-kapalai": [
        ("Sipadan North Wall", "Wall", "Advanced", ["wall", "sharks", "turtles"], ["big-animals", "advanced-challenges"]),
        ("Sipadan South Wall", "Wall", "Advanced", ["wall", "schooling barracuda", "turtles"], ["big-animals", "advanced-challenges"]),
        ("Mabul Frogfish Lair", "Shore", "Beginner", ["muck", "frogfish", "macro"], ["macro-muck", "beginner-friendly"]),
        ("Kapalai Muck", "Shore", "Beginner", ["muck", "macro", "unique critters"], ["macro-muck", "beginner-friendly"]),
        ("Smart Shoal", "Reef", "Advanced", ["schooling bigeye trevally", "sharks", "current"], ["big-animals", "advanced-challenges"]),
        ("Coral Garden Mabul", "Reef", "Beginner", ["coral garden", "macro", "reef fish"], ["beginner-friendly"]),
        ("Lobster Wall Kapalai", "Wall", "Intermediate", ["wall", "lobster", "reef fish"], []),
    ],

    "similan-surin-islands": [
        ("Richelieu Rock", "Reef", "Advanced", ["whale sharks", "seahorse", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Surin Island North", "Reef", "Intermediate", ["coral garden", "reef fish", "turtles"], []),
        ("Christmas Point", "Drift", "Advanced", ["current", "schooling fish", "manta rays"], ["big-animals", "advanced-challenges"]),
        ("Three Trees", "Reef", "Intermediate", ["coral", "reef fish", "turtles"], []),
        ("Fantasea Reef", "Reef", "Intermediate", ["staghorn coral", "reef fish"], []),
        ("Anita's Reef", "Reef", "Beginner", ["coral garden", "reef fish", "calm"], ["beginner-friendly"]),
        ("West of Eden", "Reef", "Intermediate", ["coral", "nudibranch", "macro"], ["macro-muck"]),
        ("HQ Bay", "Shore", "Beginner", ["protected bay", "reef fish", "macro"], ["beginner-friendly"]),
    ],

    "thailand-gulf": [
        ("Chumphon Pinnacle", "Reef", "Advanced", ["whale sharks", "schooling fish", "current"], ["big-animals", "advanced-challenges"]),
        ("Ang Thong Marine Park", "Reef", "Intermediate", ["national park", "reef fish", "clear water"], []),
        ("Sailrock", "Reef", "Advanced", ["chimney swimthrough", "whale sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Hin Ngam", "Reef", "Intermediate", ["smooth stones", "reef fish", "unique"], []),
        ("Southwest Pinnacle", "Reef", "Intermediate", ["pinnacle", "soft coral", "fish"], []),
        ("Shark Island Koh Tao", "Reef", "Intermediate", ["nurse sharks", "reef fish", "current"], ["big-animals"]),
        ("Tanote Bay", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
    ],

    "phuket-phi-phi-krabi": [
        ("Shark Point Phuket", "Reef", "Intermediate", ["leopard sharks", "soft coral", "reef fish"], ["big-animals"]),
        ("Anemone Reef Phuket", "Reef", "Intermediate", ["anemones", "clownfish", "reef fish"], []),
        ("King Cruiser Wreck", "Wreck", "Intermediate", ["ferry wreck", "reef fish", "soft coral"], ["wreck-capitals"]),
        ("Bida Nai Phi Phi", "Reef", "Intermediate", ["reef", "reef fish", "blacktip sharks"], ["big-animals"]),
        ("Bida Nok", "Reef", "Intermediate", ["pinnacle", "reef fish", "turtles"], []),
        ("Koh Bida", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
        ("Hin Daeng", "Wall", "Advanced", ["wall", "current", "mantas", "whalesharks"], ["big-animals", "advanced-challenges"]),
        ("Hin Muang", "Wall", "Advanced", ["wall", "purple soft coral", "mantas"], ["big-animals", "advanced-challenges"]),
        ("Phi Phi Tonsai Bay", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
    ],

    "palau": [
        ("Chandelier Cave", "Cave", "Intermediate", ["multiple chambers", "stalagmites", "marine lake"], ["caves-cenotes"]),
        ("Siaes Corner", "Wall", "Advanced", ["wall", "grey reef sharks", "current"], ["big-animals", "advanced-challenges"]),
        ("Siaes Tunnel", "Cave", "Advanced", ["tunnel", "wall", "reef fish"], ["caves-cenotes", "advanced-challenges"]),
        ("Short Drop Off", "Wall", "Intermediate", ["wall", "soft coral", "schooling fish"], []),
        ("Peleliu Wall", "Wall", "Advanced", ["wall", "current", "pelagic", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Peleliu Cut", "Drift", "Advanced", ["extreme current", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
        ("Ulong Channel", "Drift", "Advanced", ["channel", "current", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Jake Seaplane Wreck", "Wreck", "Intermediate", ["WWII seaplane", "shallow", "reef fish"], ["wreck-capitals"]),
        ("Ngerchong Inside", "Reef", "Intermediate", ["soft coral", "reef fish"], []),
        ("Goby and Pistol Shrimp Bay", "Shore", "Beginner", ["goby pairs", "sandy", "macro"], ["macro-muck", "beginner-friendly"]),
    ],

    "chuuk-truk-lagoon": [
        ("Shinkoku Maru", "Wreck", "Intermediate", ["oil tanker wreck", "coral growth", "reef fish"], ["wreck-capitals"]),
        ("Heian Maru", "Wreck", "Intermediate", ["submarine tender", "large wreck", "reef fish"], ["wreck-capitals"]),
        ("Nippo Maru", "Wreck", "Intermediate", ["cargo ship", "tanks on deck", "reef fish"], ["wreck-capitals"]),
        ("San Francisco Maru", "Wreck", "Advanced", ["deep wreck", "tanks", "history", "deep"], ["wreck-capitals", "advanced-challenges"]),
        ("Emily Flying Boat", "Wreck", "Advanced", ["WWII seaplane", "deep", "history"], ["wreck-capitals", "advanced-challenges"]),
        ("Susuki Destroyer", "Wreck", "Advanced", ["destroyer wreck", "deep", "history"], ["wreck-capitals", "advanced-challenges"]),
        ("Unkai Maru", "Wreck", "Intermediate", ["freighter wreck", "coral growth", "reef fish"], ["wreck-capitals"]),
        ("Gosei Maru", "Wreck", "Intermediate", ["subchaser wreck", "shallow", "coral"], ["wreck-capitals"]),
    ],

    "yap": [
        ("Manta Ray Bay", "Reef", "Intermediate", ["manta rays", "cleaning station", "regular sightings"], ["big-animals"]),
        ("Mi'l Channel", "Drift", "Advanced", ["manta rays", "current", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Vertigo", "Wall", "Advanced", ["sheer wall", "sharks", "current"], ["big-animals", "advanced-challenges"]),
        ("Yap Cavern", "Cave", "Intermediate", ["cavern", "reef fish", "macro"], ["caves-cenotes"]),
        ("SunkenShip", "Wreck", "Intermediate", ["WWII wreck", "reef fish"], ["wreck-capitals"]),
        ("Goofnuw Channel", "Drift", "Advanced", ["manta rays", "current", "sharks"], ["big-animals", "advanced-challenges"]),
    ],

    "sharm-el-sheikh": [
        ("Thomas Reef Sharm", "Wall", "Advanced", ["wall", "current", "tuna"], ["advanced-challenges"]),
        ("Jackfish Alley", "Reef", "Intermediate", ["schooling jacks", "reef fish", "current"], []),
        ("Fiasco", "Reef", "Intermediate", ["reef", "reef fish", "macro"], []),
        ("The Tower Sharm", "Reef", "Intermediate", ["coral tower", "reef fish"], []),
        ("Alternatives Reef", "Reef", "Beginner", ["calm", "coral garden", "fish"], ["beginner-friendly"]),
    ],

    "hurghada": [
        ("Erg Somaya", "Reef", "Intermediate", ["reef", "schooling fish", "soft coral"], []),
        ("Gota Abu Ramada", "Reef", "Intermediate", ["reef", "fish diversity"], []),
        ("Submerged Lighthouse", "Reef", "Intermediate", ["lighthouse wreck", "reef fish"], ["wreck-capitals"]),
        ("Abu Hashish Shoal", "Reef", "Intermediate", ["shoal", "reef fish", "shark"], ["big-animals"]),
    ],

    "red-sea-liveaboard": [
        ("Rocky Island Far South", "Reef", "Advanced", ["remote", "pristine", "sharks", "pelagic"], ["big-animals", "liveaboard"]),
        ("Zabargad East Wall", "Wall", "Advanced", ["wall", "pelagic", "hammerheads"], ["big-animals", "liveaboard"]),
        ("Fury Shoals South", "Reef", "Intermediate", ["pristine remote reef", "fish diversity"], ["liveaboard"]),
        ("Big Brother Island", "Wall", "Advanced", ["wall", "hammerheads", "sharks"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Little Brother Island", "Wall", "Advanced", ["wall", "oceanic whitetips", "pelagic"], ["big-animals", "liveaboard", "advanced-challenges"]),
        ("Numidia Wreck Big Brother", "Wreck", "Advanced", ["deep WWII wreck", "sharks", "history"], ["wreck-capitals", "liveaboard", "advanced-challenges"]),
        ("Aida Wreck Little Brother", "Wreck", "Advanced", ["wreck", "sharks", "history"], ["wreck-capitals", "liveaboard"]),
    ],

    "maldives-north-male-atoll": [
        ("Manta Point Lankanfinolhu", "Reef", "Intermediate", ["manta rays", "cleaning station", "regular"], ["big-animals"]),
        ("Guraidhoo Corner", "Reef", "Advanced", ["current", "sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Vadhoo Cave", "Cave", "Intermediate", ["cavern", "reef fish", "bioluminescence"], ["caves-cenotes"]),
        ("Kandooma Thila", "Reef", "Advanced", ["current", "schooling fish", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Bodu Thila", "Reef", "Advanced", ["current", "pelagic", "sharks"], ["big-animals", "advanced-challenges"]),
        ("Kolhuvaariyaafushi", "Reef", "Intermediate", ["reef", "fish diversity", "soft coral"], []),
    ],

    "maldives-ari-atoll": [
        ("Kuda Rah Thila", "Reef", "Advanced", ["current", "sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Vilamendhoo Housereef", "Shore", "Beginner", ["housereef", "turtles", "reef fish"], ["beginner-friendly"]),
        ("Fish Head South", "Reef", "Intermediate", ["fish density", "reef sharks", "coral"], ["big-animals"]),
        ("Maaya Maaa", "Reef", "Beginner", ["coral", "reef fish", "calm"], ["beginner-friendly"]),
        ("Bathala Caves", "Cave", "Intermediate", ["cavern system", "reef fish", "macro"], ["caves-cenotes"]),
    ],

    "great-barrier-reef": [
        ("Cathedral Reef", "Reef", "Intermediate", ["cathedral formation", "fish diversity"], []),
        ("Split Bommie", "Reef", "Intermediate", ["split coral formation", "fish diversity"], []),
        ("Challenger Bay", "Reef", "Beginner", ["calm lagoon", "coral", "fish"], ["beginner-friendly"]),
        ("Pixie Pinnacle", "Reef", "Intermediate", ["pinnacle", "macro", "soft coral"], ["macro-muck"]),
        ("Ron's Wall", "Wall", "Intermediate", ["wall", "fish diversity", "coral"], []),
        ("Magic Mikes", "Reef", "Intermediate", ["coral gardens", "fish", "turtles"], []),
        ("Barracuda Pass", "Reef", "Intermediate", ["barracuda", "schooling fish", "current"], []),
        ("Pixie's Pinnacle", "Reef", "Intermediate", ["pinnacle", "macro", "reef fish"], ["macro-muck"]),
    ],

    "fiji": [
        ("Mellow Yellow", "Reef", "Intermediate", ["yellow soft coral", "fish diversity"], []),
        ("Shark Corridor", "Reef", "Advanced", ["bull sharks", "current", "schooling fish"], ["big-animals", "advanced-challenges"]),
        ("Blue Ridge", "Wall", "Intermediate", ["wall", "soft coral", "fish"], []),
        ("Dreamland", "Reef", "Intermediate", ["soft coral", "reef fish"], []),
        ("Cabbage Coral Garden", "Reef", "Beginner", ["cabbage coral", "reef fish", "beginners"], ["beginner-friendly"]),
        ("Mount Mutiny", "Reef", "Advanced", ["current", "sharks", "fish"], ["big-animals", "advanced-challenges"]),
        ("Wakaya Passage", "Drift", "Advanced", ["hammerheads", "current", "pelagic"], ["big-animals", "advanced-challenges"]),
    ],

    "french-polynesia": [
        ("Taravao Pass Bora Bora", "Reef", "Intermediate", ["reef sharks", "rays", "fish"], ["big-animals"]),
        ("White Valley Rangiroa", "Reef", "Intermediate", ["white sand", "reef fish", "rays"], []),
        ("Motu Mahana Bora Bora", "Shore", "Beginner", ["snorkel", "reef fish", "rays"], ["beginner-friendly"]),
        ("Avatoru Channel", "Drift", "Intermediate", ["channel", "reef fish", "sharks"], ["big-animals"]),
        ("Manihi Atoll", "Reef", "Intermediate", ["black pearl atoll", "reef fish", "sharks"], ["big-animals"]),
        ("Niau Atoll", "Reef", "Advanced", ["remote", "pristine", "sharks"], ["big-animals", "liveaboard"]),
    ],

    "hawaii": [
        ("Kona Honu Dives", "Shore", "Beginner", ["turtles", "shore", "reef fish"], ["big-animals", "beginner-friendly"]),
        ("Place of Refuge Honaunau", "Shore", "Beginner", ["turtles", "shore entry", "reef fish"], ["beginner-friendly"]),
        ("Red Hill Kona", "Reef", "Intermediate", ["lava arches", "reef fish", "eels"], []),
        ("Manta Heaven Maui", "Reef", "Intermediate", ["manta rays", "night dive", "plankton"], ["big-animals"]),
        ("Five Caves Maui", "Cave", "Intermediate", ["lava arches", "caves", "reef fish"], ["caves-cenotes"]),
        ("Reef's End Maui", "Wall", "Intermediate", ["wall", "turtles", "pelagic"], []),
        ("Lanai Pinnacles", "Reef", "Advanced", ["pinnacles", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
    ],

    "cayman-islands": [
        ("Trinity Caves", "Cave", "Intermediate", ["multiple chambers", "reef fish", "sponges"], ["caves-cenotes"]),
        ("Grand Canyon Grand Cayman", "Reef", "Intermediate", ["swim through", "reef fish", "sponges"], []),
        ("Orange Canyon", "Reef", "Intermediate", ["orange sponges", "reef fish"], []),
        ("Japanese Gardens", "Reef", "Beginner", ["coral garden", "reef fish", "calm"], ["beginner-friendly"]),
        ("Tarpon Alley", "Reef", "Intermediate", ["tarpon school", "sponges", "coral"], []),
        ("Babylon Grand Cayman", "Wall", "Intermediate", ["deep wall", "sponges", "fish"], []),
        ("Three Fathom Wall", "Wall", "Intermediate", ["wall", "coral", "fish"], []),
    ],

    "belize": [
        ("Glover's Reef Pinnacles", "Reef", "Intermediate", ["pinnacles", "reef fish", "coral"], []),
        ("Turneffe Flats", "Reef", "Beginner", ["permit fishing", "reef fish", "flats"], ["beginner-friendly"]),
        ("Mayan Ruins Underwater", "Reef", "Intermediate", ["unique", "reef fish", "history"], []),
        ("Laughing Bird Caye", "Reef", "Beginner", ["protected caye", "reef fish", "snorkel"], ["beginner-friendly"]),
        ("Hol Chan Cut", "Drift", "Beginner", ["drift", "fish density", "turtles"], ["beginner-friendly"]),
    ],

    "bonaire": [
        ("18 Palms", "Shore", "Beginner", ["shore", "palms", "reef fish"], ["beginner-friendly"]),
        ("Margate Bay", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
        ("Red Slave", "Shore", "Intermediate", ["shore", "wall", "coral", "fish"], []),
        ("Boka Bartol", "Shore", "Intermediate", ["shore", "wall", "sponges"], []),
        ("Windsock Steep", "Wall", "Intermediate", ["wall", "fish", "coral"], []),
        ("Angel City", "Shore", "Beginner", ["coral garden", "fish", "turtles"], ["beginner-friendly"]),
    ],

    "malta-gozo": [
        ("Ta' Cenc Cliff", "Wall", "Intermediate", ["wall", "reef fish", "sponges"], []),
        ("Double Arch Reef Gozo", "Reef", "Intermediate", ["arch", "reef fish", "coral"], []),
        ("Wied il-Ghasri Valley", "Cave", "Intermediate", ["canyon", "cave entrance", "macro"], ["caves-cenotes"]),
        ("Billinghurst Cave", "Cave", "Advanced", ["cave system", "reef fish", "macro"], ["caves-cenotes", "advanced-challenges"]),
        ("Ghar Lapsi", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["beginner-friendly"]),
        ("P31 Patrol Boat Wreck", "Wreck", "Beginner", ["shallow wreck", "reef fish"], ["wreck-capitals", "beginner-friendly"]),
    ],

    "norway-lofoten": [
        ("Lofoten Wall", "Wall", "Advanced", ["cold water", "sea urchins", "kelp", "fish density"], ["cold-water", "advanced-challenges"]),
        ("Fjord Night Diving", "Shore", "Intermediate", ["bioluminescence", "cold water", "macro"], ["cold-water"]),
        ("Hammerfest", "Shore", "Intermediate", ["cold water", "king crabs", "macro"], ["cold-water"]),
        ("Tromso Wrecks", "Wreck", "Intermediate", ["WWII wrecks", "cold water", "history"], ["wreck-capitals", "cold-water"]),
        ("Alta Fjord", "Shore", "Advanced", ["cold water", "fish density", "macro"], ["cold-water", "advanced-challenges"]),
    ],

    "scotland-uk": [
        ("Wreck of the Scapa Flow Kaiser", "Wreck", "Intermediate", ["WWI battleship", "cold water", "history"], ["wreck-capitals", "cold-water"]),
        ("Chicken Rock Isle of Man", "Reef", "Advanced", ["current", "kelp", "fish density"], ["cold-water", "advanced-challenges"]),
        ("Plymouth Sound Wrecks", "Wreck", "Intermediate", ["multiple wrecks", "cold water", "history"], ["wreck-capitals", "cold-water"]),
        ("Skerries Anglesey", "Reef", "Intermediate", ["tidal races", "fish density", "kelp"], ["cold-water"]),
        ("Skomer Island", "Shore", "Intermediate", ["marine reserve", "grey seals", "cold water"], ["big-animals", "cold-water"]),
        ("Pembrokeshire Marine Park", "Shore", "Intermediate", ["marine park", "reef fish", "cold water"], ["cold-water"]),
    ],

    "canada-pacific": [
        ("Christie Passage", "Reef", "Advanced", ["nudibranchs", "wolf eels", "cold water"], ["cold-water", "macro-muck", "advanced-challenges"]),
        ("Plumper Islets", "Reef", "Intermediate", ["rockfish", "macro", "cold water"], ["cold-water"]),
        ("Sund Rock", "Shore", "Intermediate", ["giant pacific octopus", "wolf eels", "nudibranchs"], ["cold-water", "macro-muck"]),
        ("Eva Wall", "Wall", "Advanced", ["wall", "nudibranchs", "cold water"], ["cold-water", "advanced-challenges"]),
        ("Porteau Cove Wreck", "Wreck", "Beginner", ["wreck", "reef fish", "cold water"], ["wreck-capitals", "cold-water", "beginner-friendly"]),
        ("Tyee Cove", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["cold-water", "beginner-friendly"]),
    ],

    "okinawa-japan": [
        ("Miyako Blue Cave 2", "Cave", "Beginner", ["blue light effect", "reef fish"], ["caves-cenotes", "beginner-friendly"]),
        ("Irabu Island", "Reef", "Intermediate", ["reef fish", "coral", "clear water"], []),
        ("Iriomote Mangrove", "Shore", "Beginner", ["mangrove", "unique", "shore diving"], ["beginner-friendly"]),
        ("Hatoma Island", "Reef", "Intermediate", ["remote", "pristine reef", "manta rays"], ["big-animals"]),
        ("Sekisei Lagoon", "Reef", "Beginner", ["massive coral field", "turtles", "fish"], ["beginner-friendly"]),
    ],

    "izu-peninsula-japan": [
        ("Kawana", "Shore", "Intermediate", ["macro", "nudibranchs", "reef fish"], ["macro-muck"]),
        ("Ito", "Shore", "Beginner", ["shore", "reef fish", "macro"], ["macro-muck", "beginner-friendly"]),
        ("Nebukawa", "Shore", "Intermediate", ["macro", "cuttlefish", "reef fish"], ["macro-muck"]),
        ("Atami", "Shore", "Beginner", ["shore", "warm water", "macro"], ["beginner-friendly"]),
        ("Sagi Jima", "Shore", "Intermediate", ["macro", "nudibranchs", "seahorse"], ["macro-muck"]),
    ],

    "south-africa-eastern-cape": [
        ("Cathedral Peak Aliwal", "Reef", "Intermediate", ["reef", "ragged tooth sharks", "fish"], ["big-animals"]),
        ("The Park Aliwal", "Reef", "Advanced", ["ragged tooth sharks", "tiger sharks"], ["big-animals", "advanced-challenges"]),
        ("Raggie Cave", "Cave", "Intermediate", ["ragged tooth sharks", "cavern", "reef fish"], ["caves-cenotes", "big-animals"]),
        ("Pori Point", "Reef", "Intermediate", ["reef fish", "turtles", "soft coral"], []),
        ("Quarter Mile Reef", "Reef", "Advanced", ["sharks", "reef fish", "current"], ["big-animals", "advanced-challenges"]),
    ],

    "south-africa-western-cape": [
        ("Kalk Bay Reef", "Shore", "Intermediate", ["reef", "cold water", "fish density"], ["cold-water"]),
        ("Roman Rock Lighthouse", "Reef", "Advanced", ["current", "cold water", "seals"], ["cold-water", "big-animals", "advanced-challenges"]),
        ("Castle Rocks", "Shore", "Intermediate", ["cold water", "reef fish", "kelp"], ["cold-water"]),
        ("A-frame Cape Town", "Shore", "Intermediate", ["shore", "cold water", "reef fish"], ["cold-water"]),
    ],

    "sharm-el-sheikh": [
        ("Ras Umm Sid Far North", "Reef", "Intermediate", ["reef", "fish diversity", "current"], []),
        ("Turtle Bay", "Shore", "Beginner", ["turtles", "shore", "reef fish"], ["big-animals", "beginner-friendly"]),
    ],

    "galapagos": [
        ("Punta Vicente Roca", "Wall", "Advanced", ["marine iguanas", "seahorse", "Mola mola", "cold water"], ["big-animals", "advanced-challenges"]),
        ("Daphne Minor", "Reef", "Advanced", ["hammerheads", "schooling fish", "current"], ["big-animals", "advanced-challenges"]),
        ("Academy Bay Santa Cruz", "Shore", "Beginner", ["reef fish", "sea lions", "turtles"], ["big-animals", "beginner-friendly"]),
    ],

    "sea-of-cortez": [
        ("La Reina Pinnacle", "Reef", "Advanced", ["schooling hammerheads", "current", "remote"], ["big-animals", "advanced-challenges"]),
        ("Cerralvo Island", "Reef", "Advanced", ["hammerheads", "manta rays", "current"], ["big-animals", "advanced-challenges"]),
        ("Swanee Rock", "Reef", "Intermediate", ["schools of fish", "reef fish", "macro"], []),
        ("The Pinnacle La Paz", "Reef", "Advanced", ["schooling fish", "sharks", "current"], ["big-animals", "advanced-challenges"]),
    ],

    "fraser-island": [
        ("Barracuda Rock", "Reef", "Intermediate", ["reef", "barracuda", "schooling fish"], []),
    ],

    "great-barrier-reef": [
        ("Stone Island", "Reef", "Beginner", ["fringing reef", "coral", "reef fish"], ["beginner-friendly"]),
        ("Horseshoe Bay", "Shore", "Beginner", ["shore", "reef fish", "turtles"], ["beginner-friendly"]),
        ("Wheeler Reef", "Reef", "Intermediate", ["reef", "fish diversity"], []),
        ("John Brewer Reef", "Reef", "Beginner", ["outer reef", "coral", "fish"], ["beginner-friendly"]),
        ("Yongala Wreck", "Wreck", "Intermediate", ["epic wreck", "bull sharks", "manta rays"], ["wreck-capitals", "big-animals"]),
    ],

    "solomon-islands": [
        ("Uepi Point", "Wall", "Intermediate", ["wall", "fish diversity", "sharks"], ["big-animals"]),
        ("Mary Island Reef", "Reef", "Intermediate", ["pristine reef", "fish diversity"], []),
        ("Seghe Wrecks", "Wreck", "Intermediate", ["WWII wrecks", "reef fish", "history"], ["wreck-capitals"]),
        ("Nggela Lagoon", "Reef", "Beginner", ["lagoon", "coral", "fish"], ["beginner-friendly"]),
        ("Marovo Lagoon", "Reef", "Intermediate", ["world's largest lagoon", "reef fish", "pristine"], []),
    ],

    "fernando-de-noronha": [
        ("Cagarras do Norte", "Reef", "Intermediate", ["reef fish", "turtles", "dolphins"], ["big-animals"]),
        ("Laje Dois Irmaos", "Reef", "Advanced", ["current", "sharks", "fish density"], ["big-animals", "advanced-challenges"]),
        ("Ilha da Conceição", "Reef", "Intermediate", ["reef", "fish diversity", "clear water"], []),
    ],

    "new-zealand": [
        ("Stitts Reef Northland", "Reef", "Intermediate", ["reef fish", "cold water", "kelp"], ["cold-water"]),
        ("Cavalli Islands", "Reef", "Intermediate", ["reef fish", "cold water", "macro"], ["cold-water"]),
        ("Whangarei Heads", "Shore", "Beginner", ["shore", "reef fish", "cold water"], ["cold-water", "beginner-friendly"]),
    ],
}

# New regions added to existing groups — same as part C format
EXTRA_REGIONS: dict[str, list[dict]] = {

    "central-america-mexico-pacific": [
        {
            "id": "costa-rica-caribbean",
            "name": "Costa Rica Caribbean Coast",
            "country_id": "CR", "country": "Costa Rica",
            "latitude": 10.2, "longitude": -83.5,
            "bounds": {"min_lat": 9.5, "max_lat": 11.0, "min_lon": -84.0, "max_lon": -82.5},
            "tagline": "Cahuita reef and Caribbean Costa Rica",
            "best_season": "September–November, March–May",
            "defaults": {
                "averageDepth": 12.0, "maxDepth": 22.0, "averageTemp": 27.0,
                "averageVisibility": 10.0, "difficulty": "Beginner",
                "curation_score": 8.0, "popularity_score": 7.0, "access_level": "boat",
            },
            "_sites": [
                ("Cahuita National Park Reef", "Reef", "Beginner", ["protected reef", "turtles", "reef fish"], ["beginner-friendly"]),
                ("Punta Cahuita", "Reef", "Beginner", ["coral garden", "reef fish", "turtles"], ["beginner-friendly"]),
                ("Coral Garden Cahuita", "Reef", "Beginner", ["coral", "nurse sharks", "fish"], ["beginner-friendly"]),
                ("Isla Uvita", "Reef", "Intermediate", ["reef", "whale sharks seasonal", "dolphins"], ["big-animals"]),
                ("Manzanillo Reef", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
                ("Hitoy-Cerere Reserve", "Shore", "Intermediate", ["macro", "critters", "freshwater"], []),
            ],
        },
        {
            "id": "mexico-gulf-veracruz",
            "name": "Veracruz Reef System, Gulf of Mexico",
            "country_id": "MX", "country": "Mexico",
            "latitude": 19.2, "longitude": -95.8,
            "bounds": {"min_lat": 18.5, "max_lat": 20.0, "min_lon": -96.5, "max_lon": -95.5},
            "tagline": "Gulf of Mexico reefs close to history",
            "best_season": "March–August",
            "defaults": {
                "averageDepth": 12.0, "maxDepth": 22.0, "averageTemp": 27.0,
                "averageVisibility": 12.0, "difficulty": "Beginner",
                "curation_score": 8.0, "popularity_score": 7.0, "access_level": "boat",
            },
            "_sites": [
                ("Antón Lizardo Reef", "Reef", "Beginner", ["reef fish", "coral", "turtles"], ["beginner-friendly"]),
                ("Galleguilla Reef", "Reef", "Intermediate", ["reef", "fish diversity", "coral"], []),
                ("Anegada de Afuera", "Reef", "Intermediate", ["remote reef", "reef fish", "coral"], []),
                ("La Blanquilla", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                ("Topatillo Reef", "Reef", "Beginner", ["shallow reef", "reef fish", "snorkel"], ["beginner-friendly"]),
            ],
        },
    ],

    "caribbean-atlantic": [
        {
            "id": "florida-keys",
            "name": "Florida Keys",
            "country_id": "US", "country": "United States",
            "latitude": 24.8, "longitude": -81.0,
            "bounds": {"min_lat": 24.4, "max_lat": 25.5, "min_lon": -82.0, "max_lon": -80.0},
            "tagline": "Coral reefs, wrecks, and the only living barrier reef in the continental US",
            "best_season": "Year-round (December–April ideal)",
            "defaults": {
                "averageDepth": 10.0, "maxDepth": 25.0, "averageTemp": 26.0,
                "averageVisibility": 15.0, "difficulty": "Beginner",
                "curation_score": 8.5, "popularity_score": 8.5, "access_level": "boat",
            },
            "_sites": [
                ("Christ of the Abyss", "Reef", "Beginner", ["underwater statue", "reef fish", "coral"], ["beginner-friendly"]),
                ("USS Spiegel Grove Wreck", "Wreck", "Advanced", ["navy ship", "large wreck", "reef fish"], ["wreck-capitals", "advanced-challenges"]),
                ("USS Vandenberg Wreck", "Wreck", "Advanced", ["large missile tracking ship", "reef fish"], ["wreck-capitals", "advanced-challenges"]),
                ("Benwood Wreck", "Wreck", "Beginner", ["shallow freighter", "reef fish", "coral"], ["wreck-capitals", "beginner-friendly"]),
                ("Molasses Reef", "Reef", "Beginner", ["coral reef", "reef fish", "turtles"], ["beginner-friendly"]),
                ("Looe Key", "Reef", "Beginner", ["reef", "reef fish", "coral"], ["beginner-friendly"]),
                ("Delta Shoals", "Reef", "Beginner", ["shallow reef", "reef fish", "coral"], ["beginner-friendly"]),
                ("Eagle Wreck", "Wreck", "Intermediate", ["freighter wreck", "reef fish", "coral"], ["wreck-capitals"]),
                ("Conch Reef", "Reef", "Intermediate", ["deeper reef", "reef fish", "sponges"], []),
                ("Tennessee Reef", "Reef", "Intermediate", ["reef", "fish diversity", "coral"], []),
                ("Sombrero Reef", "Reef", "Beginner", ["lighthouse reef", "reef fish", "coral"], ["beginner-friendly"]),
                ("Nine-Foot Stake", "Reef", "Beginner", ["shallow", "reef fish", "snorkel"], ["beginner-friendly"]),
            ],
        },
    ],

    "cold-water-north-atlantic": [
        {
            "id": "northeast-usa",
            "name": "New England & Northeast USA",
            "country_id": "US", "country": "United States",
            "latitude": 42.5, "longitude": -70.5,
            "bounds": {"min_lat": 41.0, "max_lat": 45.0, "min_lon": -72.0, "max_lon": -67.0},
            "tagline": "Cold Atlantic wrecks and lobster capital",
            "best_season": "June–October",
            "defaults": {
                "averageDepth": 12.0, "maxDepth": 25.0, "averageTemp": 14.0,
                "averageVisibility": 8.0, "difficulty": "Intermediate",
                "curation_score": 7.8, "popularity_score": 7.0, "access_level": "boat",
            },
            "_sites": [
                ("Portland Lightship Wreck", "Wreck", "Intermediate", ["lightship wreck", "reef fish", "lobster"], ["wreck-capitals", "cold-water"]),
                ("Stellwagen Bank", "Reef", "Intermediate", ["humpback whales", "reef fish", "cold Atlantic"], ["big-animals", "cold-water"]),
                ("Thresher Shoal", "Reef", "Intermediate", ["reef fish", "lobster", "cold water"], ["cold-water"]),
                ("Race Point", "Reef", "Advanced", ["current", "cold water", "fish density"], ["cold-water", "advanced-challenges"]),
                ("Gloucester Sea Caves", "Cave", "Intermediate", ["sea caves", "reef fish", "cold water"], ["caves-cenotes", "cold-water"]),
                ("Cashes Ledge", "Reef", "Advanced", ["remote", "cold water", "pristine kelp forest"], ["cold-water", "advanced-challenges"]),
                ("Boon Island", "Reef", "Intermediate", ["cold water", "reef fish", "seals"], ["cold-water", "big-animals"]),
                ("Pemaquid Point", "Shore", "Intermediate", ["shore", "cold water", "lobster"], ["cold-water"]),
            ],
        },
    ],

    "south-america": [
        {
            "id": "galapagos-mainland-ecuador",
            "name": "Ecuador Mainland Coast",
            "country_id": "EC", "country": "Ecuador",
            "latitude": -1.8, "longitude": -80.7,
            "bounds": {"min_lat": -4.0, "max_lat": 1.5, "min_lon": -81.5, "max_lon": -75.0},
            "tagline": "Humpback whales and mainland Pacific Ecuador",
            "best_season": "December–May",
            "defaults": {
                "averageDepth": 14.0, "maxDepth": 25.0, "averageTemp": 22.0,
                "averageVisibility": 8.0, "difficulty": "Intermediate",
                "curation_score": 8.0, "popularity_score": 7.0, "access_level": "boat",
            },
            "_sites": [
                ("Isla de la Plata Ecuador", "Reef", "Intermediate", ["whale sharks", "mantas", "reef fish", "humpbacks"], ["big-animals"]),
                ("Bahia Drake", "Reef", "Intermediate", ["reef fish", "dolphins", "whale seasonal"], ["big-animals"]),
                ("Salango Island", "Reef", "Intermediate", ["reef", "fish diversity", "macro"], []),
                ("La Chocolatera", "Shore", "Beginner", ["sea lions", "shore", "reef fish"], ["big-animals", "beginner-friendly"]),
                ("Machalilla Park Outer", "Reef", "Advanced", ["humpback whales", "sharks", "remote"], ["big-animals", "advanced-challenges"]),
                ("Punta Carnero", "Reef", "Advanced", ["cold current", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
            ],
        },
    ],

    "japan-east-asia": [
        {
            "id": "ogasawara-islands",
            "name": "Ogasawara (Bonin) Islands",
            "country_id": "JP", "country": "Japan",
            "latitude": 27.1, "longitude": 142.2,
            "bounds": {"min_lat": 24.0, "max_lat": 27.8, "min_lon": 141.0, "max_lon": 143.0},
            "tagline": "Darwin's Japan — endemic species 1,000km from Tokyo",
            "best_season": "April–November",
            "defaults": {
                "averageDepth": 18.0, "maxDepth": 35.0, "averageTemp": 26.0,
                "averageVisibility": 25.0, "difficulty": "Intermediate",
                "curation_score": 9.3, "popularity_score": 7.5, "access_level": "liveaboard",
            },
            "_sites": [
                ("Chichi-jima Reefs", "Reef", "Intermediate", ["endemic fish", "clear water", "dolphins"], ["big-animals"]),
                ("Father Island Wall", "Wall", "Advanced", ["wall", "pelagic", "hammerheads"], ["big-animals", "advanced-challenges"]),
                ("Haha-jima Reefs", "Reef", "Advanced", ["remote", "pristine", "endemic species"], ["liveaboard"]),
                ("Dolphin Lagoon", "Shore", "Beginner", ["spinner dolphins", "reef fish", "clear water"], ["big-animals", "beginner-friendly"]),
                ("Minami-jima", "Reef", "Advanced", ["remote uninhabited", "pristine", "sharks"], ["big-animals", "liveaboard", "advanced-challenges"]),
                ("South Island Arch", "Cave", "Intermediate", ["natural arch", "reef fish", "clear water"], ["caves-cenotes"]),
                ("Iwo-jima", "Reef", "Advanced", ["WWII history", "remote", "pristine reef"], ["liveaboard", "advanced-challenges"]),
                ("Hammerhead Shoal", "Reef", "Advanced", ["hammerheads", "whale sharks", "current"], ["big-animals", "liveaboard", "advanced-challenges"]),
            ],
        },
    ],

    "east-africa-arabia": [
        {
            "id": "comoros-mayotte",
            "name": "Comoros & Mayotte",
            "country_id": "KM", "country": "Comoros",
            "latitude": -12.3, "longitude": 44.3,
            "bounds": {"min_lat": -13.0, "max_lat": -11.3, "min_lon": 43.2, "max_lon": 45.5},
            "tagline": "Coelacanth country — rare living fossil encounters",
            "best_season": "April–November",
            "defaults": {
                "averageDepth": 16.0, "maxDepth": 35.0, "averageTemp": 27.0,
                "averageVisibility": 18.0, "difficulty": "Intermediate",
                "curation_score": 8.8, "popularity_score": 6.5, "access_level": "boat",
            },
            "_sites": [
                ("Coelacanth Cavern Comoros", "Cave", "Advanced", ["coelacanth habitat", "deep cave", "rare sighting", "unique"], ["caves-cenotes", "advanced-challenges"]),
                ("Ngazidja (Grand Comore) Reefs", "Reef", "Intermediate", ["reef fish", "coral", "volcanic island"], []),
                ("Mayotte Lagoon", "Reef", "Intermediate", ["large lagoon", "reef fish", "turtles", "dolphins"], ["big-animals"]),
                ("Passe Bandeli", "Drift", "Intermediate", ["channel", "current", "sharks", "fish"], ["big-animals"]),
                ("Banc Vailheu", "Reef", "Advanced", ["remote seamount", "hammerheads", "pelagic"], ["big-animals", "advanced-challenges"]),
                ("Longoni Bay", "Shore", "Beginner", ["shore", "reef fish", "coral"], ["beginner-friendly"]),
                ("Moya Beach Reef", "Shore", "Beginner", ["shore", "turtles", "reef fish"], ["big-animals", "beginner-friendly"]),
                ("Saziley Point", "Reef", "Advanced", ["current", "sharks", "pelagic"], ["big-animals", "advanced-challenges"]),
            ],
        },
    ],
}
