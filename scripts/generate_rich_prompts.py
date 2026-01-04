#!/usr/bin/env python3
"""
Generate rich, detailed illustration prompts for marine species.
Enriches sparse descriptions with taxonomic knowledge and visual details.
"""

import json
import csv
import re
from pathlib import Path

# Detailed visual characteristics by taxonomic family/genus
FAMILY_DETAILS = {
    # SHARKS
    "sphyrnidae": {
        "body": "distinctive laterally expanded cephalofoil (hammer-shaped head) with eyes positioned at the outer edges, tall sickle-shaped first dorsal fin, asymmetrical caudal fin with elongated upper lobe",
        "texture": "smooth dermal denticles giving a sleek, almost metallic appearance",
        "colors": "bronze-olive dorsally transitioning to pale cream ventrally, with dusky fin tips",
    },
    "carcharhinidae": {
        "body": "streamlined torpedo-shaped body with pointed snout, five gill slits, prominent triangular first dorsal fin, crescent-shaped caudal fin",
        "texture": "fine dermal denticles creating a sandpaper-like skin texture",
        "colors": "grey to bronze-grey dorsally, sharply counter-shaded to white underneath",
    },
    "rhincodontidae": {
        "body": "massive flattened head with terminal mouth, tiny eyes, prominent ridges along flanks, broad caudal fin with large upper lobe",
        "texture": "thick skin marked with distinctive checkerboard pattern of pale spots and stripes",
        "colors": "deep blue-grey to greenish-brown with matrix of cream-white spots and vertical stripes",
    },
    "alopiidae": {
        "body": "small head with large eyes, extremely elongated upper caudal lobe (often as long as body), slender body",
        "texture": "smooth, almost polished appearance",
        "colors": "metallic blue-grey dorsally, white underneath, with bronze iridescence",
    },
    "lamnidae": {
        "body": "robust spindle-shaped body, conical snout, large black eyes, crescent-shaped caudal fin with nearly equal lobes, prominent keel on caudal peduncle",
        "texture": "dense dermal denticles with subtle ridges",
        "colors": "slate-blue to grey dorsally, stark white ventrally with clear demarcation line",
    },
    "ginglymostomatidae": {
        "body": "flattened head with barbels near nostrils, small eyes, rounded fins, elongated caudal fin",
        "texture": "smooth skin with subtle spotted pattern",
        "colors": "yellowish-brown to grey-brown with scattered dark spots",
    },
    "triakidae": {
        "body": "slender elongated body, oval eyes with nictitating membranes, small mouth with pavement-like teeth",
        "texture": "smooth with fine denticles",
        "colors": "grey-brown with darker saddle markings, pale underneath",
    },
    "heterodontidae": {
        "body": "blunt head with prominent ridges above eyes, pig-like snout, two dorsal fins each with leading spine",
        "texture": "rough skin with harness-like pattern of dark bands",
        "colors": "tan to brown with dark brown saddles and spots",
    },
    "orectolobidae": {
        "body": "flattened body, branching dermal lobes (barbels) around mouth, broad pectoral fins",
        "texture": "ornate reticulated pattern resembling carpet or mosaic",
        "colors": "tan, brown, and cream in intricate symmetrical patterns",
    },
    "stegostomatidae": {
        "body": "elongated body with ridges, very long caudal fin nearly half body length, small mouth",
        "texture": "prominent ridges along body, juvenile spots become adult stripes",
        "colors": "tan to brown with dark spots (juvenile) or pale with dark saddles (adult)",
    },

    # RAYS
    "mobulidae": {
        "body": "enormous diamond-shaped disc with pointed wing tips, cephalic fins (horn-like projections), whip-like tail without spine",
        "texture": "smooth velvety skin dorsally, sometimes with pale shoulder patches",
        "colors": "jet black to dark brown dorsally, pure white ventrally with distinctive spot patterns",
    },
    "myliobatidae": {
        "body": "diamond-shaped disc with pointed wing tips, distinct head projecting beyond disc, long whip tail with venomous spine",
        "texture": "smooth upper surface with distinctive pattern",
        "colors": "dark blue-grey to olive with matrix of golden-white spots or rings",
    },
    "dasyatidae": {
        "body": "flat diamond or oval disc, eyes on top of head, whip-like tail with serrated venomous spine",
        "texture": "smooth to slightly rough upper surface, often with tubercles",
        "colors": "grey to brown dorsally, often with subtle spots, white underneath",
    },
    "rhinopteridae": {
        "body": "distinct bi-lobed head resembling cow nose, diamond-shaped disc, long thin tail",
        "texture": "smooth skin with subtle patterns",
        "colors": "brown to olive-grey dorsally, white ventrally",
    },
    "rajidae": {
        "body": "rhomboid disc with pointed snout, two small dorsal fins near tail tip, thorny ridges along back",
        "texture": "rough with scattered thorns and prickles",
        "colors": "mottled brown and grey with spots and blotches for camouflage",
    },
    "torpedinidae": {
        "body": "rounded disc with kidney-shaped electric organs, short stout tail with caudal fin",
        "texture": "smooth, soft skin",
        "colors": "uniform brown to grey, sometimes with darker spots or mottling",
    },

    # TURTLES
    "cheloniidae": {
        "body": "streamlined oval carapace, powerful paddle-shaped flippers, non-retractable head with beak-like jaws",
        "texture": "keratinous scutes covering bony shell, patterns vary by species",
        "colors": "olive-brown to reddish-brown carapace, pale yellow to cream plastron",
    },
    "dermochelyidae": {
        "body": "largest turtle, teardrop-shaped carapace with seven longitudinal ridges, enormous front flippers",
        "texture": "leathery skin instead of scutes, smooth rubbery appearance",
        "colors": "dark blue-black with scattered white or pink spots",
    },

    # BONY FISH - GROUPERS & BASS
    "serranidae": {
        "body": "robust laterally compressed body, large mouth with protruding lower jaw, spiny dorsal fin continuous with soft dorsal",
        "texture": "ctenoid scales giving slightly rough texture, often spotted or barred",
        "colors": "highly variable - browns, reds, oranges with spots, bars, or mottling",
    },
    "epinephelidae": {
        "body": "heavy-bodied, large head with wide gape, strong opercular spines, rounded caudal fin",
        "texture": "small ctenoid scales, often with hexagonal or honeycomb pattern",
        "colors": "mottled browns, tans, and greys with darker spots or saddles",
    },

    # WRASSES
    "labridae": {
        "body": "elongated to moderately deep body, terminal protractile mouth with prominent lips, continuous dorsal fin, cycloid scales",
        "texture": "smooth rounded scales, often with iridescent sheen",
        "colors": "extraordinarily varied - often brilliant blues, greens, pinks, yellows with complex patterns",
    },

    # PARROTFISH
    "scaridae": {
        "body": "robust body, fused beak-like teeth (dental plates), continuous dorsal fin, large cycloid scales",
        "texture": "large prominent scales like tiles or shingles",
        "colors": "often brilliant - turquoise, emerald, coral, pink - changes dramatically with age and sex",
    },

    # BUTTERFLYFISH
    "chaetodontidae": {
        "body": "deep laterally compressed disc-shaped body, small protractile mouth with brush-like teeth, continuous dorsal fin",
        "texture": "fine ctenoid scales, often with chevron patterns",
        "colors": "typically bold yellows and whites with dark eye bands and distinctive markings",
    },

    # ANGELFISH
    "pomacanthidae": {
        "body": "deep, strongly compressed body, small mouth, distinctive spine at corner of preopercle, continuous dorsal fin",
        "texture": "ctenoid scales, often with subtle patterns",
        "colors": "spectacular - electric blues, vivid yellows, bold stripes or circles",
    },

    # SURGEONFISH & TANGS
    "acanthuridae": {
        "body": "oval compressed body, small mouth with single row of teeth, sharp scalpel-like spine on caudal peduncle",
        "texture": "small ctenoid scales giving velvety appearance",
        "colors": "often solid colors - powder blue, yellow, purple - with contrasting accents",
    },

    # TRIGGERFISH
    "balistidae": {
        "body": "deep compressed rhomboid body, small terminal mouth with strong incisiform teeth, first dorsal spine locks erect",
        "texture": "large plate-like scales forming armor",
        "colors": "bold geometric patterns - lines, spots, patches in greys, browns, blues, yellows",
    },

    # PUFFERFISH
    "tetraodontidae": {
        "body": "rounded body capable of inflation, fused beak-like teeth, no pelvic fins, tiny pectoral fins",
        "texture": "scaleless with small prickles, spotted or mottled pattern",
        "colors": "typically tan, brown, grey with dark spots and pale belly",
    },

    # BOXFISH
    "ostraciidae": {
        "body": "rigid boxy body encased in fused bony plates, small terminal mouth, tiny fins",
        "texture": "hexagonal bony plates forming carapace, honeycomb appearance",
        "colors": "often yellow with black spots, or blue-grey with intricate patterns",
    },

    # SCORPIONFISH & LIONFISH
    "scorpaenidae": {
        "body": "large head with bony ridges and spines, venomous dorsal spines, fan-like pectoral fins",
        "texture": "rough with fleshy appendages and skin flaps for camouflage",
        "colors": "mottled reds, browns, pinks - cryptic coloration matching reef substrate",
    },
    "pterois": {
        "body": "elongated body with dramatically extended venomous dorsal spines, huge fan-like pectoral fins spread like wings",
        "texture": "relatively smooth with fleshy tentacles above eyes",
        "colors": "bold alternating maroon/brown and cream-white vertical stripes",
    },

    # MORAY EELS
    "muraenidae": {
        "body": "elongated serpentine body, no pectoral or pelvic fins, continuous dorsal fin, large mouth with prominent teeth, gill openings reduced to small pores",
        "texture": "scaleless thick leathery skin, often mottled",
        "colors": "browns, greens, yellows often with spots, speckles, or intricate patterns",
    },

    # SNAPPERS
    "lutjanidae": {
        "body": "moderately deep body, large canine teeth, continuous dorsal fin with spines and soft rays, forked caudal fin",
        "texture": "moderate-sized ctenoid scales",
        "colors": "often pinks, reds, or silvers with yellow accents and distinctive lateral stripes",
    },

    # JACKS & TREVALLIES
    "carangidae": {
        "body": "streamlined compressed body, deeply forked caudal fin, scutes along lateral line, two separate dorsal fins",
        "texture": "small cycloid scales, enlarged scutes near tail",
        "colors": "silvery to blue-green with yellow accents, often with dark spots",
    },

    # DAMSELFISH
    "pomacentridae": {
        "body": "small oval compressed body, small terminal mouth, single continuous dorsal fin, forked caudal fin",
        "texture": "moderate ctenoid scales, often iridescent",
        "colors": "brilliant blues, yellows, or bicolored patterns, some with orange accents",
    },

    # GOBIES
    "gobiidae": {
        "body": "elongated small body, fused pelvic fins forming suction disc, large head with high-set eyes, rounded fins",
        "texture": "small cycloid scales, often translucent",
        "colors": "highly variable - often browns and tans with spots, bars, or bright accents",
    },

    # BLENNIES
    "blenniidae": {
        "body": "elongated compressed body, blunt head with high-set eyes, often with cirri (fleshy tentacles) above eyes, long continuous dorsal fin",
        "texture": "scaleless or with minute embedded scales, slimy skin",
        "colors": "mottled browns, greens, often with bars or spots",
    },

    # SEAHORSES & PIPEFISH
    "syngnathidae": {
        "body": "elongated body encased in bony rings, tubular snout with tiny terminal mouth, prehensile tail (seahorses) or caudal fin (pipefish)",
        "texture": "bony armor of segmented rings, sometimes with skin filaments",
        "colors": "variable - browns, yellows, reds, often matching habitat",
    },

    # BARRACUDA
    "sphyraenidae": {
        "body": "extremely elongated pike-like body, large head with jutting lower jaw, prominent fang-like teeth, widely separated dorsal fins",
        "texture": "small smooth cycloid scales giving silvery sheen",
        "colors": "silvery blue-grey with darker chevron or bar markings",
    },

    # OCTOPUSES
    "octopodidae": {
        "body": "soft mantle (head) with eight arms bearing two rows of suckers, large complex eyes, no internal shell, siphon for jet propulsion",
        "texture": "highly textured skin with ability to change texture from smooth to papillate, chromatophores for color change",
        "colors": "extraordinarily variable - browns, reds, whites - can flash patterns and textures instantly",
    },

    # SQUIDS
    "loliginidae": {
        "body": "torpedo-shaped mantle with triangular fins, eight arms plus two longer tentacles with suckers, large eyes, internal gladius (pen)",
        "texture": "smooth muscular mantle with chromatophores",
        "colors": "translucent white to pink with ability to flash iridescent colors and patterns",
    },
    "ommastrephidae": {
        "body": "muscular torpedo-shaped mantle, rhomboid fins, large eyes, powerful arms and tentacles",
        "texture": "firm muscular skin with photophores (light organs)",
        "colors": "deep red to purple, with bioluminescent spots",
    },

    # CUTTLEFISH
    "sepiidae": {
        "body": "oval flattened mantle with undulating lateral fins running full length, eight arms with two retractable tentacles, internal cuttlebone",
        "texture": "remarkable skin with papillae and chromatophores for instant texture/color change, W-shaped pupil",
        "colors": "master of camouflage - can produce waves of color, zebra patterns, or match any substrate",
    },

    # CRABS - Swimming
    "portunidae": {
        "body": "broad carapace with lateral spines, fifth pair of legs flattened into paddle-shaped swimming appendages, strong chelipeds (claws)",
        "texture": "smooth to granular carapace surface, sometimes with ridges",
        "colors": "blue, olive, brown, or mottled with distinctive markings on claws",
    },

    # CRABS - General
    "grapsidae": {
        "body": "square-shaped carapace, strong walking legs, relatively small chelipeds",
        "texture": "smooth to slightly granular carapace",
        "colors": "dark green, brown, or mottled with red or orange accents",
    },
    "xanthidae": {
        "body": "oval heavy-bodied carapace, stout powerful chelipeds, walking legs",
        "texture": "often granular or ridged carapace with rounded margins",
        "colors": "various browns, reds, or black, often with white-tipped claws",
    },
    "majidae": {
        "body": "triangular or pear-shaped carapace, long spindly legs, small chelipeds, often with rostrum (forward projection)",
        "texture": "often covered with hooked setae that hold camouflaging materials",
        "colors": "variable, often decorated with algae, sponges, hydroids",
    },
    "calappidae": {
        "body": "distinctive rounded carapace with lateral extensions covering legs, large flattened chelipeds held against body",
        "texture": "smooth dome-like carapace, often with nodules",
        "colors": "cream, tan, or yellow with reddish spots or mottling",
    },

    # LOBSTERS
    "palinuridae": {
        "body": "cylindrical cephalothorax with prominent spines, long whip-like antennae (longer than body), no large claws, powerful tail fan",
        "texture": "spiny armored exoskeleton, often with bright colors",
        "colors": "browns, greens, blues with yellow, white, or purple markings at leg joints",
    },
    "nephropidae": {
        "body": "elongated cephalothorax, one pair of large asymmetrical claws (crusher and cutter), stalked eyes, segmented abdomen",
        "texture": "heavily armored rough exoskeleton",
        "colors": "mottled blue-green to brown (live), red when cooked",
    },
    "scyllaridae": {
        "body": "flattened body, short plate-like antennae (no long whips), flattened leg segments, no claws",
        "texture": "rough sculptured carapace with ridges",
        "colors": "tan, brown, or reddish with mottled patterns",
    },

    # SHRIMP
    "penaeidae": {
        "body": "laterally compressed body, long rostrum (beak-like projection), long antennae, pleopods (swimming legs), fan-shaped tail",
        "texture": "smooth translucent exoskeleton",
        "colors": "pink, brown, or grey, often with banding patterns",
    },
    "palaemonidae": {
        "body": "slender translucent body, long toothed rostrum, long whip-like antennae, elongated second pair of legs with small pincers",
        "texture": "nearly transparent exoskeleton revealing internal organs",
        "colors": "glass-clear with white, red, or purple bands and spots",
    },
    "stenopodidae": {
        "body": "compressed body, long rostrum, extremely elongated third pair of legs with small pincers, banded pattern",
        "texture": "spiny exoskeleton on carapace",
        "colors": "brilliant red and white banded pattern",
    },
    "alpheidae": {
        "body": "robust compressed body, extremely asymmetrical claws (one massive snapping claw), short rostrum",
        "texture": "smooth to slightly hairy exoskeleton",
        "colors": "various - often red, orange, green, or mottled patterns",
    },
    "hippolytidae": {
        "body": "small slender compressed body, prominent rostrum, often with humpback appearance",
        "texture": "smooth translucent exoskeleton",
        "colors": "variable to match habitat - often transparent, red, or green",
    },

    # NUDIBRANCHS
    "chromodorididae": {
        "body": "elongated oval soft body, pair of rhinophores (sensory tentacles) on head, branchial plume (feathery gills) on posterior",
        "texture": "smooth to slightly tuberculate mantle, no shell",
        "colors": "spectacular - vivid blues, oranges, purples, yellows with contrasting spots, stripes, or borders",
    },
    "flabellinidae": {
        "body": "elongated body covered in cerata (finger-like projections), pair of rhinophores, oral tentacles",
        "texture": "body covered with rows of cerata containing digestive glands",
        "colors": "often purple, pink, or orange with contrasting cerata tips",
    },
    "phyllidiidae": {
        "body": "oval body with raised tubercles, no visible gills, rhinophores retract into pockets",
        "texture": "warty/tuberculate dorsum with compound tubercles",
        "colors": "typically black with yellow, pink, or white tubercles and ridges",
    },

    # JELLYFISH
    "rhizostomeae": {
        "body": "dome-shaped bell with no tentacles, eight branching oral arms, no central mouth",
        "texture": "translucent gelatinous bell with subtle radial patterns",
        "colors": "white, blue, pink, or brown, often with darker margins or spots",
    },
    "pelagiidae": {
        "body": "hemispherical bell with 24+ long trailing tentacles, four frilled oral arms",
        "texture": "translucent bell with visible radial canals",
        "colors": "pink, purple, or brown with banded tentacles",
    },
    "cyaneidae": {
        "body": "broad flat bell up to 2m wide, masses of long trailing tentacles, large convoluted oral arms",
        "texture": "thick gelatinous bell with radial lobes",
        "colors": "red, orange, or yellow, with darker tentacles",
    },
    "cassiopeidae": {
        "body": "flattened bell typically resting upside-down, branching oral arms containing symbiotic algae",
        "texture": "firm bell with frilled edges",
        "colors": "brown, green, or blue due to symbiotic zooxanthellae",
    },
    "ulmaridae": {
        "body": "translucent dome-shaped bell, gonads visible as four horseshoe-shaped organs, trailing oral arms",
        "texture": "crystalline transparent bell",
        "colors": "nearly transparent with white, pink, or purple tinged organs",
    },

    # STARFISH
    "asteroidea": {
        "body": "central disc with five (or more) radiating arms, tube feet on underside, eyespot at arm tips, mouth on underside",
        "texture": "surface covered with spines, tubercles, or granules depending on species",
        "colors": "oranges, reds, blues, purples, often patterned",
    },
    "oreasteridae": {
        "body": "large inflated body, short thick arms, heavily armored",
        "texture": "covered with conical tubercles and spines in patterns",
        "colors": "bright oranges, reds, sometimes with darker reticulated patterns",
    },
    "acanthasteridae": {
        "body": "large disc with 7-23 arms covered in venomous spines",
        "texture": "densely covered in sharp spines",
        "colors": "grey-green, purple, or brown with contrasting spine colors",
    },
    "ophidiasteridae": {
        "body": "small disc with long cylindrical smooth arms",
        "texture": "smooth with small granules",
        "colors": "blues, reds, oranges, often solid colors",
    },

    # SEA URCHINS
    "echinoidea": {
        "body": "spherical to flattened test (shell) with five-fold symmetry, moveable spines, tube feet, central mouth with Aristotle's lantern (teeth)",
        "texture": "test covered in moveable spines of varying lengths",
        "colors": "black, purple, red, green, or white with contrasting spines",
    },
    "diadematidae": {
        "body": "spherical test with extremely long needle-like spines, some venomous",
        "texture": "long hollow spines up to 30cm, banded in some species",
        "colors": "black or banded black and white spines",
    },
    "echinometridae": {
        "body": "oval test with moderate-length stout spines, wedged into rock crevices",
        "texture": "thick blunt spines",
        "colors": "dark purple, green, or brown",
    },
    "toxopneustidae": {
        "body": "spherical test with short spines and prominent pedicellariae (pincers), highly venomous",
        "texture": "short spines with flower-like pedicellariae",
        "colors": "red, pink, or white with dark-tipped pedicellariae",
    },

    # SEA CUCUMBERS
    "holothuroidea": {
        "body": "elongated sausage-shaped body, leathery body wall, tube feet, ring of feeding tentacles around mouth",
        "texture": "leathery often warty skin, some smooth",
        "colors": "blacks, browns, reds, with spots or patterns",
    },
    "holothuriidae": {
        "body": "large cylindrical body, ventral tube feet for locomotion, dorsal papillae",
        "texture": "tough leathery skin, often warty or papillate",
        "colors": "often dark - brown, black, or mottled",
    },
    "stichopodidae": {
        "body": "large body with squared cross-section, lateral 'wings', prominent papillae",
        "texture": "thick body wall with conical papillae",
        "colors": "variable - often with contrasting spots or patches",
    },

    # ANEMONES
    "actiniaria": {
        "body": "cylindrical column attached to substrate, oral disc surrounded by rings of tentacles, no skeleton",
        "texture": "smooth or verrucose column, tentacles with nematocysts",
        "colors": "highly variable - greens, browns, pinks, purples, often with contrasting tentacle tips",
    },
    "stichodactylidae": {
        "body": "flat oral disc with carpet of short tentacles, hosts clownfish",
        "texture": "dense coverage of sticky short tentacles",
        "colors": "browns, greens, purples, often with fluorescent tips",
    },
    "heteractidae": {
        "body": "large oral disc with long bubble-tipped or slender tentacles",
        "texture": "tentacles often with bulbous tips, sometimes spiraling",
        "colors": "tan, brown, green, purple, with contrasting tentacle tips",
    },

    # CLOWNFISH/ANEMONEFISH
    "amphiprioninae": {
        "body": "small oval laterally compressed body, rounded fins, symbiotic mucus coating",
        "texture": "small cycloid scales with mucus coating for anemone protection",
        "colors": "typically orange, red, or black with white vertical bars edged in black",
    },

    # MULLETS
    "mugilidae": {
        "body": "torpedo-shaped body, broad flattened head, two widely separated dorsal fins, thick lips",
        "texture": "large cycloid scales, adipose eyelid",
        "colors": "silvery sides, olive-grey back, often with faint longitudinal stripes",
    },

    # DOLPHINS
    "delphinidae": {
        "body": "streamlined fusiform body, prominent dorsal fin, elongated beak (rostrum), horizontal tail flukes, flippers",
        "texture": "smooth rubbery skin, hairless",
        "colors": "grey dorsally, lighter ventrally, often with cape and eye stripe patterns",
    },

    # FROGFISH
    "antennariidae": {
        "body": "globular body with leg-like pectoral fins, small upward-facing mouth, illicium (fishing rod lure) on head",
        "texture": "covered in wart-like bumps and skin filaments, highly camouflaged",
        "colors": "extremely variable - matches substrate exactly: yellows, reds, blacks, sometimes with spots or saddles",
    },

    # FLATFISH
    "bothidae": {
        "body": "extremely compressed oval body, both eyes on one side (usually left), continuous dorsal and anal fins",
        "texture": "scaled with ability to match substrate pattern",
        "colors": "sandy browns and tans with mottled camouflage pattern",
    },

    # CARDINALFISH
    "apogonidae": {
        "body": "small oval compressed body, large eyes, two separate dorsal fins, large mouth",
        "texture": "large ctenoid scales, often slightly rough",
        "colors": "reds, oranges, silvers, often with stripes or spots",
    },

    # HAWKFISH
    "cirrhitidae": {
        "body": "small robust body, pointed snout, cirri (tufts) on dorsal fin spines, thickened lower pectoral rays",
        "texture": "ctenoid scales with distinctive dorsal fin tufts",
        "colors": "often red, orange, or white with spots, bands, or checkerboard patterns",
    },

    # RABBITFISH
    "siganidae": {
        "body": "deep oval compressed body, small rabbit-like mouth, venomous dorsal and anal spines",
        "texture": "small cycloid scales, slimy coating",
        "colors": "often silver-grey with yellow markings, or spotted patterns, can rapidly change",
    },

    # FILEFISH
    "monacanthidae": {
        "body": "deep compressed body, rough sandpaper-like skin, single prominent dorsal spine",
        "texture": "tiny scales with minute spinules giving sandpaper texture",
        "colors": "variable - often with intricate patterns of spots, lines, or network markings",
    },

    # DRAGONETS
    "callionymidae": {
        "body": "elongated flattened body, very broad head, large showy dorsal fin (males), small gill openings",
        "texture": "scaleless slimy skin, often with intricate patterns",
        "colors": "males often brilliantly colored with blues, oranges, complex patterns",
    },

    # TUBE WORMS
    "sabellidae": {
        "body": "segmented worm body in parchment tube, elaborate feathery branchial crown (radioles) for feeding and respiration",
        "texture": "soft body in secreted tube, delicate spiral or fan-shaped feeding crown",
        "colors": "radioles often banded - browns, oranges, whites, sometimes purple or blue",
    },
    "serpulidae": {
        "body": "segmented worm in calcareous (hard) tube, feathery radiole crown, operculum (door) to close tube",
        "texture": "white calcareous tube, delicate spiral or fan-shaped crown",
        "colors": "varied - often red, orange, blue, banded or spotted radioles",
    },

    # SPONGES
    "porifera": {
        "body": "varied forms - encrusting, branching, tubular, or massive; oscula (excurrent openings) visible, no true tissues",
        "texture": "porous surface with numerous small ostia (incurrent pores)",
        "colors": "reds, oranges, yellows, purples, blues - many bright colors",
    },

    # MANTIS SHRIMP
    "stomatopoda": {
        "body": "elongated flattened body, large stalked eyes with unique vision, powerful raptorial appendages (spearers or smashers)",
        "texture": "armored carapace in segments, often with keels and spines",
        "colors": "often spectacular - greens, blues, reds with contrasting patterns, iridescent eyes",
    },

    # HERMIT CRABS
    "paguridae": {
        "body": "soft asymmetrical abdomen carried in gastropod shell, long antennae, right claw larger, only front body armored",
        "texture": "calcified claws and legs, soft vulnerable abdomen hidden in shell",
        "colors": "claws often red, orange, or blue with patterns; legs banded or striped",
    },
    "diogenidae": {
        "body": "similar to paguridae but left claw usually larger, often with equal-sized claws",
        "texture": "heavy claws sometimes used to block shell opening",
        "colors": "often brightly colored claws - blues, oranges, reds",
    },
    "coenobitidae": {
        "body": "adapted for land, stalked eyes, asymmetrical abdomen in shells, gills modified for air breathing",
        "texture": "heavily armored front, soft abdomen protected by shell",
        "colors": "often purple, red, or orange legs with dark markings",
    },

    # CLAMS & BIVALVES
    "tridacnidae": {
        "body": "massive shell, fleshy mantle with symbiotic algae exposed between shell valves",
        "texture": "thick fluted shell valves, iridescent wavy mantle",
        "colors": "mantle shows brilliant blues, greens, golds, purples due to zooxanthellae and iridophores",
    },
    "cardiidae": {
        "body": "heart-shaped when viewed from end, strong radial ribs, prominent umbo",
        "texture": "pronounced radial ribs, sometimes with spines or scales",
        "colors": "white, cream, brown, sometimes with patterns",
    },
    "ostreidae": {
        "body": "irregular shape, one valve cupped and cemented to substrate, other valve flat",
        "texture": "rough laminated surface, often encrusted",
        "colors": "grey, brown, or purplish exterior, nacreous white interior",
    },
    "pectinidae": {
        "body": "distinctive fan shape with radiating ribs, rows of eyes along mantle edge, can swim by valve clapping",
        "texture": "ridged shells, wing-like 'ears' near hinge",
        "colors": "often orange, red, yellow, purple, or white with concentric banding",
    },
    "pinnidae": {
        "body": "large triangular shell, anchored in substrate by byssus threads",
        "texture": "thin fragile shell with fine radial ribs",
        "colors": "amber, brown, or dark olive, often translucent",
    },

    # CONE SNAILS
    "conidae": {
        "body": "cone-shaped shell with narrow aperture, specialized venomous radula, siphon for detecting prey",
        "texture": "smooth polished shell surface with patterns",
        "colors": "diverse patterns - tented, banded, reticulated in browns, oranges, whites",
    },

    # COWRIES
    "cypraeidae": {
        "body": "highly polished oval shell with toothed aperture, mantle can cover entire shell",
        "texture": "exceptionally smooth porcelain-like surface",
        "colors": "often spotted or banded - tiger patterns, rings, or solid colors",
    },

    # DEFAULT FISH
    "default_fish": {
        "body": "streamlined fusiform body with distinct head, trunk, and tail regions, paired pectoral and pelvic fins, median dorsal, anal, and caudal fins",
        "texture": "overlapping cycloid or ctenoid scales, lateral line visible",
        "colors": "often silver with darker dorsum and lighter ventrum (counter-shading)",
    },
    "default_invertebrate": {
        "body": "marine invertebrate with specialized body plan adapted to reef environment",
        "texture": "variable depending on phylum - may be soft-bodied or with exoskeleton/shell",
        "colors": "often cryptic or aposematic coloration",
    },
}

# View descriptions based on body type
VIEW_BY_TYPE = {
    "shark": "Full lateral view showing complete body profile from snout to caudal fin, with all fin positions clearly visible.",
    "hammerhead": "Three-quarter anterior-lateral view to showcase the distinctive cephalofoil head shape while showing body profile.",
    "ray": "Dorsal view from directly above to display the full disc shape, wing span, and tail.",
    "manta": "Oblique dorsal view showing the magnificent wingspan, cephalic fins, and elegant gliding posture.",
    "turtle": "Three-quarter dorsal-lateral view displaying the carapace pattern, head profile, and flipper structure.",
    "octopus": "Naturalistic pose with body and arms artfully arranged to show suckers, skin texture, and characteristic large eye.",
    "squid": "Full lateral view showing mantle shape, fin position, arm and tentacle arrangement, and large eye.",
    "cuttlefish": "Slight lateral-dorsal view showing oval mantle, undulating fin, arms, and distinctive W-shaped eye.",
    "crab": "Dorsal view from above showing full carapace shape, cheliped (claw) size and detail, and walking leg arrangement.",
    "lobster": "Full lateral view showing cephalothorax, abdomen segmentation, antenna length, and claw detail.",
    "shrimp": "Lateral view showing body curvature, rostrum, antenna, swimming legs, and tail fan.",
    "nudibranch": "Dorsal-oblique view to display rhinophores, branchial plume or cerata, and mantle ornamentation.",
    "jellyfish": "View from below looking up through translucent bell showing radial symmetry and trailing tentacles/oral arms.",
    "starfish": "Dorsal view showing arm arrangement, surface texture, and central disc.",
    "urchin": "Oblique view showing spherical test shape and spine arrangement.",
    "cucumber": "Lateral view showing elongated body, tube feet, and feeding tentacles.",
    "anemone": "View from above and slightly angled to show tentacle crown and oral disc pattern.",
    "seahorse": "Classic lateral view showing curved posture, horse-like head, and prehensile tail.",
    "eel": "Sinuous S-curve pose showing serpentine body form and fin structure.",
    "moray": "Head and anterior body emerging from rocky crevice, mouth slightly open to show dentition.",
    "fish_deep": "Full lateral view emphasizing the deep, laterally compressed body and elaborate finnage.",
    "fish_elongated": "Full lateral view showing the stretched proportions and streamlined form.",
    "fish_standard": "Classic lateral view showing complete body profile with all fins visible and detailed scaling.",
    "bivalve": "View showing both valves with one slightly open to reveal mantle, or dorsal view of matched valves.",
    "gastropod": "Apertural view showing shell spiral, aperture, and surface ornamentation.",
    "worm": "Lateral view of body with feeding crown expanded, or emerging from tube.",
    "sponge": "View showing growth form, oscula, and surface texture.",
}


def get_family_from_scientific(scientific_name: str) -> str:
    """Try to determine family from scientific name patterns."""
    genus = scientific_name.split()[0].lower() if scientific_name else ""

    # Map genera to families
    genus_to_family = {
        # Sharks
        "sphyrna": "sphyrnidae",
        "carcharhinus": "carcharhinidae",
        "negaprion": "carcharhinidae",
        "triaenodon": "carcharhinidae",
        "galeocerdo": "carcharhinidae",
        "prionace": "carcharhinidae",
        "rhincodon": "rhincodontidae",
        "alopias": "alopiidae",
        "carcharodon": "lamnidae",
        "isurus": "lamnidae",
        "ginglymostoma": "ginglymostomatidae",
        "nebrius": "ginglymostomatidae",
        "mustelus": "triakidae",
        "heterodontus": "heterodontidae",
        "orectolobus": "orectolobidae",
        "stegostoma": "stegostomatidae",
        "chiloscyllium": "hemiscylliidae",

        # Rays
        "mobula": "mobulidae",
        "manta": "mobulidae",
        "aetobatus": "myliobatidae",
        "myliobatis": "myliobatidae",
        "dasyatis": "dasyatidae",
        "taeniura": "dasyatidae",
        "himantura": "dasyatidae",
        "pastinachus": "dasyatidae",
        "neotrygon": "dasyatidae",
        "rhinoptera": "rhinopteridae",
        "raja": "rajidae",
        "torpedo": "torpedinidae",

        # Turtles
        "chelonia": "cheloniidae",
        "caretta": "cheloniidae",
        "eretmochelys": "cheloniidae",
        "lepidochelys": "cheloniidae",
        "dermochelys": "dermochelyidae",

        # Groupers
        "epinephelus": "epinephelidae",
        "cephalopholis": "epinephelidae",
        "plectropomus": "epinephelidae",
        "variola": "epinephelidae",
        "mycteroperca": "epinephelidae",

        # Wrasses
        "thalassoma": "labridae",
        "coris": "labridae",
        "halichoeres": "labridae",
        "labroides": "labridae",
        "cheilinus": "labridae",
        "bodianus": "labridae",
        "oxycheilinus": "labridae",
        "novaculichthys": "labridae",

        # Parrotfish
        "scarus": "scaridae",
        "chlorurus": "scaridae",
        "hipposcarus": "scaridae",
        "bolbometopon": "scaridae",
        "cetoscarus": "scaridae",

        # Butterflyfish
        "chaetodon": "chaetodontidae",
        "heniochus": "chaetodontidae",
        "forcipiger": "chaetodontidae",
        "chelmon": "chaetodontidae",

        # Angelfish
        "pomacanthus": "pomacanthidae",
        "pygoplites": "pomacanthidae",
        "centropyge": "pomacanthidae",
        "apolemichthys": "pomacanthidae",
        "holacanthus": "pomacanthidae",

        # Surgeonfish
        "acanthurus": "acanthuridae",
        "paracanthurus": "acanthuridae",
        "zebrasoma": "acanthuridae",
        "naso": "acanthuridae",
        "ctenochaetus": "acanthuridae",

        # Triggerfish
        "balistoides": "balistidae",
        "rhinecanthus": "balistidae",
        "odonus": "balistidae",
        "sufflamen": "balistidae",
        "melichthys": "balistidae",
        "balistapus": "balistidae",

        # Pufferfish
        "arothron": "tetraodontidae",
        "canthigaster": "tetraodontidae",
        "diodon": "diodontidae",
        "chilomycterus": "diodontidae",

        # Boxfish
        "ostracion": "ostraciidae",
        "lactoria": "ostraciidae",

        # Scorpionfish & Lionfish
        "scorpaenopsis": "scorpaenidae",
        "scorpaena": "scorpaenidae",
        "pterois": "pterois",
        "dendrochirus": "pterois",

        # Moray
        "gymnothorax": "muraenidae",
        "echidna": "muraenidae",
        "rhinomuraena": "muraenidae",
        "enchelycore": "muraenidae",

        # Snappers
        "lutjanus": "lutjanidae",
        "macolor": "lutjanidae",
        "aprion": "lutjanidae",

        # Jacks
        "caranx": "carangidae",
        "gnathanodon": "carangidae",
        "trachinotus": "carangidae",
        "scomberoides": "carangidae",
        "elagatis": "carangidae",

        # Damselfish
        "amphiprion": "amphiprioninae",
        "premnas": "amphiprioninae",
        "chromis": "pomacentridae",
        "dascyllus": "pomacentridae",
        "abudefduf": "pomacentridae",
        "pomacentrus": "pomacentridae",
        "stegastes": "pomacentridae",

        # Gobies
        "gobidon": "gobiidae",
        "valenciennea": "gobiidae",
        "amblyeleotris": "gobiidae",
        "stonogobiops": "gobiidae",

        # Blennies
        "ecsenius": "blenniidae",
        "meiacanthus": "blenniidae",
        "salarias": "blenniidae",

        # Seahorses & Pipefish
        "hippocampus": "syngnathidae",
        "syngnathus": "syngnathidae",
        "corythoichthys": "syngnathidae",
        "doryrhamphus": "syngnathidae",

        # Barracuda
        "sphyraena": "sphyraenidae",

        # Octopuses
        "octopus": "octopodidae",
        "amphioctopus": "octopodidae",
        "hapalochlaena": "octopodidae",
        "thaumoctopus": "octopodidae",
        "abdopus": "octopodidae",
        "callistoctopus": "octopodidae",
        "wunderpus": "octopodidae",

        # Squid
        "sepioteuthis": "loliginidae",
        "loligo": "loliginidae",

        # Cuttlefish
        "sepia": "sepiidae",
        "metasepia": "sepiidae",

        # Swimming crabs
        "portunus": "portunidae",
        "callinectes": "portunidae",
        "charybdis": "portunidae",
        "thalamita": "portunidae",
        "podophthalmus": "portunidae",
        "lupocyclus": "portunidae",

        # Other crabs
        "grapsus": "grapsidae",
        "pachygrapsus": "grapsidae",
        "percnon": "grapsidae",
        "carpilius": "xanthidae",
        "actaea": "xanthidae",
        "atergatis": "xanthidae",
        "pilumnus": "xanthidae",
        "zosimus": "xanthidae",
        "lophozozymus": "xanthidae",
        "majidae": "majidae",
        "calappa": "calappidae",
        "dromia": "dromiidae",
        "dardanus": "diogenidae",
        "calcinus": "diogenidae",
        "clibanarius": "diogenidae",
        "pagurus": "paguridae",
        "coenobita": "coenobitidae",
        "birgus": "coenobitidae",
        "petrolisthes": "porcellanidae",
        "neopetrolisthes": "porcellanidae",

        # Lobsters
        "panulirus": "palinuridae",
        "palinurus": "palinuridae",
        "enoplometopus": "nephropidae",
        "scyllarides": "scyllaridae",
        "thenus": "scyllaridae",

        # Shrimp
        "penaeus": "penaeidae",
        "palaemon": "palaemonidae",
        "periclimenes": "palaemonidae",
        "ancylomenes": "palaemonidae",
        "urocaridella": "palaemonidae",
        "stenopus": "stenopodidae",
        "alpheus": "alpheidae",
        "synalpheus": "alpheidae",
        "lysmata": "hippolytidae",
        "thor": "hippolytidae",
        "rhynchocinetes": "rhynchocinetidae",
        "saron": "hippolytidae",
        "hymenocera": "hymenoceridae",

        # Nudibranchs
        "chromodoris": "chromodorididae",
        "glossodoris": "chromodorididae",
        "hypselodoris": "chromodorididae",
        "nembrotha": "polyceridae",
        "phyllidia": "phyllidiidae",
        "phyllidiella": "phyllidiidae",
        "flabellina": "flabellinidae",
        "pteraeolidia": "aeolidiidae",
        "jorunna": "discodorididae",
        "halgerda": "discodorididae",
        "hexabranchus": "hexabranchidae",

        # Jellyfish
        "aurelia": "ulmaridae",
        "cassiopea": "cassiopeidae",
        "mastigias": "mastigiidae",
        "thysanostoma": "thysanostomatidae",
        "rhopilema": "rhizostomatidae",
        "cyanea": "cyaneidae",
        "chrysaora": "pelagiidae",
        "pelagia": "pelagiidae",

        # Starfish
        "linckia": "ophidiasteridae",
        "fromia": "ophidiasteridae",
        "nardoa": "ophidiasteridae",
        "oreaster": "oreasteridae",
        "culcita": "oreasteridae",
        "protoreaster": "oreasteridae",
        "acanthaster": "acanthasteridae",
        "asterias": "asteriidae",
        "coscinasterias": "asteriidae",
        "echinaster": "echinasteridae",

        # Sea urchins
        "diadema": "diadematidae",
        "echinothrix": "diadematidae",
        "echinometra": "echinometridae",
        "tripneustes": "toxopneustidae",
        "toxopneustes": "toxopneustidae",
        "asthenosoma": "echinothuriidae",
        "colobocentrotus": "echinometridae",
        "heterocentrotus": "echinometridae",

        # Sea cucumbers
        "holothuria": "holothuriidae",
        "actinopyga": "holothuriidae",
        "bohadschia": "holothuriidae",
        "stichopus": "stichopodidae",
        "thelenota": "stichopodidae",
        "synapta": "synaptidae",

        # Anemones
        "stichodactyla": "stichodactylidae",
        "heteractis": "heteractidae",
        "entacmaea": "actiniidae",
        "macrodactyla": "actiniidae",
        "condylactis": "actiniidae",

        # Clams
        "tridacna": "tridacnidae",

        # Mantis shrimp
        "odontodactylus": "stomatopoda",
        "gonodactylus": "stomatopoda",
        "lysiosquilla": "stomatopoda",

        # Mullets
        "mugil": "mugilidae",

        # Dolphins
        "tursiops": "delphinidae",
        "delphinus": "delphinidae",
        "stenella": "delphinidae",

        # Frogfish
        "antennarius": "antennariidae",
        "antennatus": "antennariidae",
        "histrio": "antennariidae",

        # Flatfish
        "bothus": "bothidae",

        # Cardinalfish
        "apogon": "apogonidae",
        "ostorhinchus": "apogonidae",
        "cheilodipterus": "apogonidae",
        "pterapogon": "apogonidae",

        # Hawkfish
        "cirrhitichthys": "cirrhitidae",
        "paracirrhites": "cirrhitidae",
        "oxycirrhites": "cirrhitidae",

        # Rabbitfish
        "siganus": "siganidae",
        "lo": "siganidae",

        # Filefish
        "aluterus": "monacanthidae",
        "cantherhines": "monacanthidae",
        "pervagor": "monacanthidae",
        "oxymonacanthus": "monacanthidae",

        # Dragonets
        "synchiropus": "callionymidae",
        "callionymus": "callionymidae",

        # Tube worms
        "sabellastarte": "sabellidae",
        "spirobranchus": "serpulidae",
        "protula": "serpulidae",
    }

    return genus_to_family.get(genus, None)


def get_view_type(name: str, description: str, family: str) -> str:
    """Determine the appropriate view type for illustration."""
    combined = f"{name} {description}".lower()

    if family in ["sphyrnidae"]:
        return "hammerhead"
    if family in ["carcharhinidae", "lamnidae", "alopiidae", "triakidae", "ginglymostomatidae",
                  "heterodontidae", "orectolobidae", "stegostomatidae", "rhincodontidae"]:
        return "shark"
    if family in ["mobulidae"]:
        return "manta"
    if family in ["myliobatidae", "dasyatidae", "rhinopteridae", "rajidae", "torpedinidae"]:
        return "ray"
    if family in ["cheloniidae", "dermochelyidae"]:
        return "turtle"
    if family in ["octopodidae"]:
        return "octopus"
    if family in ["loliginidae", "ommastrephidae"]:
        return "squid"
    if family in ["sepiidae"]:
        return "cuttlefish"
    if family in ["portunidae", "grapsidae", "xanthidae", "majidae", "calappidae",
                  "paguridae", "diogenidae", "coenobitidae", "dromiidae", "porcellanidae"]:
        return "crab"
    if family in ["palinuridae", "nephropidae", "scyllaridae"]:
        return "lobster"
    if family in ["penaeidae", "palaemonidae", "stenopodidae", "alpheidae", "hippolytidae",
                  "rhynchocinetidae", "hymenoceridae"]:
        return "shrimp"
    if family in ["chromodorididae", "flabellinidae", "phyllidiidae", "polyceridae",
                  "aeolidiidae", "discodorididae", "hexabranchidae"]:
        return "nudibranch"
    if family in ["ulmaridae", "cassiopeidae", "mastigiidae", "rhizostomatidae",
                  "cyaneidae", "pelagiidae", "thysanostomatidae"]:
        return "jellyfish"
    if family in ["ophidiasteridae", "oreasteridae", "acanthasteridae", "asteriidae", "echinasteridae"]:
        return "starfish"
    if family in ["diadematidae", "echinometridae", "toxopneustidae", "echinothuriidae"]:
        return "urchin"
    if family in ["holothuriidae", "stichopodidae", "synaptidae"]:
        return "cucumber"
    if family in ["stichodactylidae", "heteractidae", "actiniidae"]:
        return "anemone"
    if family in ["syngnathidae"] and "seahorse" in combined:
        return "seahorse"
    if family in ["syngnathidae"]:
        return "fish_elongated"
    if family in ["muraenidae"]:
        return "moray"
    if "eel" in combined:
        return "eel"
    if family in ["chaetodontidae", "pomacanthidae", "acanthuridae", "balistidae"]:
        return "fish_deep"
    if family in ["sphyraenidae", "callionymidae"]:
        return "fish_elongated"
    if family in ["tridacnidae", "cardiidae", "ostreidae", "pectinidae", "pinnidae"]:
        return "bivalve"
    if family in ["conidae", "cypraeidae"]:
        return "gastropod"
    if family in ["sabellidae", "serpulidae"]:
        return "worm"
    if family in ["porifera"]:
        return "sponge"
    if family in ["stomatopoda"]:
        return "shrimp"
    if family in ["delphinidae"]:
        return "fish_standard"

    # Fallback based on keywords
    if "crab" in combined:
        return "crab"
    if "shrimp" in combined or "prawn" in combined:
        return "shrimp"
    if "octopus" in combined:
        return "octopus"
    if "squid" in combined:
        return "squid"
    if "jellyfish" in combined or "jelly" in combined:
        return "jellyfish"
    if "starfish" in combined or "sea star" in combined:
        return "starfish"
    if "urchin" in combined:
        return "urchin"
    if "nudibranch" in combined or "sea slug" in combined:
        return "nudibranch"

    return "fish_standard"


def build_rich_description(species: dict, family: str) -> str:
    """Build a rich, detailed anatomical description."""
    name = species["name"]
    desc = species.get("description", "") or ""

    # Get family details if available
    family_info = FAMILY_DETAILS.get(family)

    if not family_info:
        # Try to infer from description keywords
        desc_lower = desc.lower()
        if "shark" in desc_lower:
            family_info = FAMILY_DETAILS.get("carcharhinidae")
        elif "ray" in desc_lower:
            family_info = FAMILY_DETAILS.get("dasyatidae")
        elif "crab" in desc_lower:
            family_info = FAMILY_DETAILS.get("portunidae") if "swim" in desc_lower else FAMILY_DETAILS.get("xanthidae")
        elif "shrimp" in desc_lower or "prawn" in desc_lower:
            family_info = FAMILY_DETAILS.get("penaeidae")
        elif "octopus" in desc_lower:
            family_info = FAMILY_DETAILS.get("octopodidae")
        elif "squid" in desc_lower:
            family_info = FAMILY_DETAILS.get("loliginidae")
        elif "nudibranch" in desc_lower or "sea slug" in desc_lower:
            family_info = FAMILY_DETAILS.get("chromodorididae")
        elif "jellyfish" in desc_lower:
            family_info = FAMILY_DETAILS.get("ulmaridae")
        elif "starfish" in desc_lower or "sea star" in desc_lower:
            family_info = FAMILY_DETAILS.get("asteroidea")
        elif "urchin" in desc_lower:
            family_info = FAMILY_DETAILS.get("echinoidea")
        elif "invertebrate" in desc_lower:
            family_info = FAMILY_DETAILS.get("default_invertebrate")
        else:
            family_info = FAMILY_DETAILS.get("default_fish")

    if not family_info:
        family_info = FAMILY_DETAILS.get("default_fish")

    # Extract any specific details from original description
    original_details = ""
    if desc and ":" in desc:
        original_details = desc.split(":", 1)[1].strip()
    elif desc:
        original_details = desc

    # Build anatomical description
    body = family_info.get("body", "")
    texture = family_info.get("texture", "")
    colors = family_info.get("colors", "")

    # Combine information
    parts = []

    if body:
        parts.append(f"Anatomical features: {body}")

    if texture:
        parts.append(f"Surface texture: {texture}")

    # Include relevant original details if they add information
    if original_details and len(original_details) > 20:
        # Filter out generic phrases
        generic_phrases = ["marine fish", "found on coral reefs", "marine invertebrate", "reef fish"]
        filtered_details = original_details
        for phrase in generic_phrases:
            filtered_details = filtered_details.replace(phrase, "").strip()
        if len(filtered_details) > 15:
            parts.append(f"Distinctive characteristics: {filtered_details}")

    if colors:
        parts.append(f"Coloration: {colors}")

    return " ".join(parts)


def generate_prompt(species: dict) -> str:
    """Generate a complete, detailed illustration prompt."""
    name = species["name"]
    scientific_name = species["scientificName"]

    # Determine taxonomic family
    family = get_family_from_scientific(scientific_name)
    if not family:
        # Try to infer from name/description
        combined = f"{name} {species.get('description', '')}".lower()
        if "shark" in combined:
            family = "carcharhinidae"
        elif "ray" in combined:
            family = "dasyatidae"
        elif "turtle" in combined:
            family = "cheloniidae"

    # Get view type
    view_type = get_view_type(name, species.get("description", ""), family or "")
    view_description = VIEW_BY_TYPE.get(view_type, VIEW_BY_TYPE["fish_standard"])

    # Build rich anatomical description
    rich_description = build_rich_description(species, family or "default_fish")

    # Get colors from family info
    family_info = FAMILY_DETAILS.get(family or "default_fish", FAMILY_DETAILS["default_fish"])
    colors = family_info.get("colors", "natural coloration with subtle iridescence")

    prompt = f"""A scientific biological illustration plate of a {name} ({scientific_name}), rendered in exquisite 19th-century chromolithograph style.

COMPOSITION: {view_description} The specimen is centered on the plate with ample space to appreciate anatomical details.

SUBJECT DETAILS: {rich_description}

ARTISTIC TECHNIQUE: The illustration employs masterful stippling (pointillism) for tonal gradation, with delicate cross-hatching to define form and volume. Fine brushwork captures the subtle textures. Watercolor washes in naturalistic tones: {colors}. Edges are defined purely through color value transitions and textural contrast—there are absolutely NO heavy black outlines or cartoon-like borders.

AESTHETIC: The plate has the organic, aged quality of an archival museum specimen illustration. Paper texture is subtly visible. The overall impression is of a precious scientific document from a 19th-century natural history expedition.

BACKGROUND: Solid, uniform deep navy blue (#0B1C2C), providing dramatic contrast that makes the specimen luminous."""

    return prompt


def main():
    input_path = Path("/Users/finn/dev/umilog/data/export/species_catalog_full.json")
    output_json = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts.json")
    output_csv = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts.csv")

    with open(input_path) as f:
        data = json.load(f)

    species_list = data["species"]
    results = []

    for species in species_list:
        prompt = generate_prompt(species)
        results.append({
            "id": species["id"],
            "name": species["name"],
            "scientificName": species["scientificName"],
            "prompt": prompt
        })

    # Write JSON
    with open(output_json, "w") as f:
        json.dump({"prompts": results, "count": len(results)}, f, indent=2)

    # Write CSV
    with open(output_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "name", "scientificName", "prompt"])
        writer.writeheader()
        writer.writerows(results)

    print(f"Generated {len(results)} rich prompts")
    print(f"JSON: {output_json}")
    print(f"CSV: {output_csv}")

    # Print samples
    print("\n" + "="*80)
    print("SAMPLE PROMPTS")
    print("="*80)

    # Show diverse samples
    samples = ["Blacktip Reef Shark", "Great Hammerhead Shark", "Reef Manta Ray",
               "Common Octopus", "Lionfish", "striped pyjama nudibranch",
               "green turtle", "blue swimming crab", "southern pink shrimp"]

    for sample_name in samples:
        for r in results:
            if r["name"].lower() == sample_name.lower():
                print(f"\n--- {r['name']} ({r['scientificName']}) ---\n")
                print(r["prompt"])
                print()
                break


if __name__ == "__main__":
    main()
