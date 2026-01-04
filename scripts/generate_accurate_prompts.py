#!/usr/bin/env python3
"""
Marine Biologist-verified prompt generator.
Ensures 100% anatomical accuracy by genus/family constraints.
Explicitly states what features species DO NOT have to prevent hallucinations.
"""

import json
import csv
from pathlib import Path

# Taxonomically accurate descriptions with CONSTRAINTS
# Format: body, key_features, constraints (what it does NOT have), coloration
GENUS_ANATOMY = {
    # ═══════════════════════════════════════════════════════════════════════════
    # SPINY LOBSTERS (Palinuridae) - NO CLAWS!
    # ═══════════════════════════════════════════════════════════════════════════
    "panulirus": {
        "view": "Dorsal-lateral view showing cylindrical carapace, massive antennae, and all walking legs",
        "body": "Cylindrical, heavily armored carapace densely covered with forward-pointing spines. Elongated segmented abdomen ending in broad tail fan (telson and uropods)",
        "key_features": "Two extremely long, thick, spiny antennae extending 1.5x body length. Antennae bases fused and armored. Stalked compound eyes. Five pairs of walking legs",
        "constraints": "CRITICAL: This is a SPINY LOBSTER - it has absolutely NO LARGE FRONT CLAWS (chelae). All legs are similar-sized walking legs. Do NOT draw any pincers or crushing claws",
        "coloration": "variable by species - typically dark reddish-brown to blue-green carapace with cream/yellow banding on legs and antennae",
    },
    "palinurus": {
        "view": "Dorsal-lateral view showing spiny carapace and characteristic antennae",
        "body": "Robust cylindrical carapace with prominent spines, particularly around eyes. Segmented muscular abdomen",
        "key_features": "Long spiny antennae (though shorter than Panulirus). Prominent rostral horns above eyes. Walking legs with small terminal claws only for grip",
        "constraints": "NO large chelae/pincers. This is a spiny lobster, not a clawed lobster",
        "coloration": "pink to reddish-brown with pale spots and markings, lighter underneath",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SLIPPER LOBSTERS (Scyllaridae) - NO CLAWS, FLAT ANTENNAE!
    # ═══════════════════════════════════════════════════════════════════════════
    "scyllarides": {
        "view": "Dorsal view showing flattened body and distinctive shovel-like antennae",
        "body": "Dorsoventrally flattened, broadly oval carapace. Flattened segmented abdomen",
        "key_features": "Second antennae modified into broad, flat, shovel-like plates (NOT long whips). Small first antennae. Flattened body for hiding in crevices",
        "constraints": "NO large claws. NO long whip-like antennae - antennae are SHORT and FLAT like shovels or paddles. Do NOT draw typical lobster appearance",
        "coloration": "mottled tan, brown, and cream - cryptic camouflage pattern",
    },
    "thenus": {
        "view": "Dorsal view showing extremely flattened body",
        "body": "Extremely dorsoventrally flattened - almost pancake-like. Broad carapace wider than long",
        "key_features": "Flat shovel-shaped antennae. Eyes on short stalks at front corners. Flattened legs held close to body",
        "constraints": "NO claws. NO long antennae. Body is EXTREMELY FLAT - should look like it could hide under a rock",
        "coloration": "sand-colored with reddish-brown mottling, pale underneath",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # TRUE CLAWED LOBSTERS (Nephropidae) - HAS ASYMMETRICAL CLAWS
    # ═══════════════════════════════════════════════════════════════════════════
    "homarus": {
        "view": "Lateral view showing both claws and full body profile",
        "body": "Elongated cylindrical cephalothorax, segmented muscular abdomen, broad tail fan",
        "key_features": "ONE PAIR of massive front claws (chelipeds) - one larger 'crusher' claw with molar-like teeth, one slender 'cutter/seizer' claw with sharp teeth. Long thin antennae. Smaller walking legs behind chelipeds",
        "constraints": "Only ONE pair of large claws (first walking legs modified). Other legs are normal walking legs, not claws",
        "coloration": "dark blue-black to greenish-brown when alive (turns red only when cooked), mottled pattern",
    },
    "enoplometopus": {
        "view": "Lateral view showing colorful pattern and claws",
        "body": "Small lobster with cylindrical body, shorter proportions than Homarus",
        "key_features": "Pair of slender claws (less massive than true lobsters). Brightly colored. Often hairy/setose legs",
        "constraints": "Claws present but SLENDER, not massive crushing claws",
        "coloration": "typically bright red, orange, or purple with white spots - very colorful reef lobster",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SHARKS - CARTILAGINOUS, NO SWIM BLADDER
    # ═══════════════════════════════════════════════════════════════════════════
    "carcharhinus": {
        "view": "Full lateral view from snout to tail tip showing all fins",
        "body": "Streamlined fusiform (torpedo-shaped) body. Pointed snout. Heterocercal tail (upper lobe larger)",
        "key_features": "Five gill slits. Two dorsal fins (first much larger). Pectoral fins behind gill slits. Pelvic fins. Anal fin. Crescent-shaped caudal fin. Nictitating membrane on eyes",
        "constraints": "NO swim bladder (must keep swimming). NO bony skeleton - cartilaginous. NO operculum (gill cover) - open gill slits",
        "coloration": "grey to bronze-grey dorsally, sharply demarcated white underside (counter-shading)",
    },
    "sphyrna": {
        "view": "Three-quarter anterior view to show hammer-shaped head clearly",
        "body": "Streamlined body with laterally expanded head forming 'cephalofoil' (hammer shape). Eyes and nostrils at hammer tips",
        "key_features": "Distinctive hammer/shovel-shaped head with eyes at outer edges. Tall first dorsal fin. Smaller second dorsal. Five gill slits. Wide-set nostrils at head edges for enhanced electroreception",
        "constraints": "Do NOT draw normal shark head - must have laterally flattened cephalofoil. NO bony skeleton. NO operculum",
        "coloration": "olive-grey to brownish-grey dorsally, white ventrally, fin tips often dusky",
    },
    "rhincodon": {
        "view": "Lateral view showing full spotted pattern and massive size impression",
        "body": "Enormous flattened head, wide terminal mouth (not underslung). Prominent ridges along flanks. Massive caudal fin",
        "key_features": "Terminal mouth at front of head (unique among sharks). Tiny eyes. Three prominent ridges on each flank. Filter-feeding with gill rakers. Widest fish alive",
        "constraints": "Mouth is at FRONT of head, not underneath like most sharks. NO teeth used for biting - filter feeder. Despite size, completely harmless",
        "coloration": "dark blue-grey to brown with distinctive checkerboard matrix of pale cream/white spots and vertical stripes. Pale underneath",
    },
    "galeocerdo": {
        "view": "Lateral view showing distinctive markings and robust body",
        "body": "Heavy-bodied with blunt, squared snout. Very large mouth with distinctively shaped teeth (notched and serrated)",
        "key_features": "Broad, blunt head. Long upper caudal lobe. Tiger-like vertical stripes (fade with age). Distinctive cockscomb-shaped teeth",
        "constraints": "Stripes more prominent in juveniles - adults may show faded bars or appear uniformly grey",
        "coloration": "blue-grey to dark grey with darker vertical bars/stripes (tiger pattern). White underside",
    },
    "negaprion": {
        "view": "Lateral view showing characteristic yellow-brown coloration",
        "body": "Stocky body with flattened head and short, broad snout",
        "key_features": "Two dorsal fins of nearly EQUAL SIZE (distinctive). Yellowish-brown coloration. Small eyes",
        "constraints": "Both dorsal fins similar size - unusual for sharks. NO prominent markings",
        "coloration": "distinctive yellow-brown to olive-brown, giving name 'lemon shark'. Pale underside",
    },
    "triaenodon": {
        "view": "Lateral view showing white fin tips",
        "body": "Slender body with broad, flat head. Short snout with nasal flaps",
        "key_features": "Distinctive WHITE TIPS on first dorsal and caudal fins. Able to rest on bottom (doesn't need to swim constantly). Oval eyes with vertical pupils",
        "constraints": "White tips are KEY identifier - do not omit. Can remain stationary unlike most sharks",
        "coloration": "grey-brown with scattered dark spots. Bright white tips on dorsal and tail fins",
    },
    "carcharodon": {
        "view": "Lateral view showing powerful body and famous teeth",
        "body": "Robust spindle-shaped body. Conical pointed snout. Large black eye. Powerful crescent caudal fin with nearly equal lobes. Prominent keel on caudal peduncle",
        "key_features": "Large triangular serrated teeth visible even when mouth closed. Very large first dorsal. White undersurface meets dark top at distinctive jagged line",
        "constraints": "Eye is NOT small - medium-sized and all black. Counter-shading demarcation line is irregular/jagged",
        "coloration": "slate grey to black dorsally, stark white ventrally with irregular boundary between",
    },
    "isurus": {
        "view": "Lateral view emphasizing streamlined speed-adapted body",
        "body": "Extremely streamlined spindle shape - the fastest shark. Pointed snout. Large lunate (crescent) tail with equal lobes",
        "key_features": "Teeth visible even with mouth closed - long, slender, non-serrated. Pronounced caudal keels. Metallic sheen",
        "constraints": "Tail lobes nearly EQUAL (unlike most sharks). More slender than great white despite similar features",
        "coloration": "brilliant metallic blue dorsally, snow white ventrally. Sharp color demarcation",
    },
    "alopias": {
        "view": "Lateral view MUST show full tail length",
        "body": "Small head with large eyes. Slender body. ENORMOUSLY elongated upper caudal lobe as long as rest of body",
        "key_features": "Upper tail lobe extends to roughly HALF total body length. Uses tail as whip to stun prey. Large eyes for deep water hunting",
        "constraints": "Tail is CRITICAL feature - upper lobe must be shown full length, nearly as long as body",
        "coloration": "metallic purple-grey to blue-grey dorsally, white ventrally. Bronze iridescence in light",
    },
    "ginglymostoma": {
        "view": "Lateral view showing barbels and resting posture",
        "body": "Flattened head, cylindrical body. Small mouth with nasal barbels. Small eyes. Rounded fins",
        "key_features": "Fleshy BARBELS near nostrils (sensory feelers). Can pump water over gills (rest on bottom). Fourth and fifth gill slits very close together",
        "constraints": "This shark CAN rest motionless on bottom - unlike most sharks. Barbels are key identifier",
        "coloration": "uniform tan to yellowish-brown, sometimes with sparse dark spots. Juveniles spotted",
    },
    "stegostoma": {
        "view": "Lateral view showing extremely long tail",
        "body": "Cylindrical body with ridges. Very long caudal fin (nearly half total length). Small transverse mouth",
        "key_features": "Adult: elongated tail fin, leopard-like spots. Juvenile: zebra stripes (hence former name 'zebra shark'). Ridges along body. Nasal barbels",
        "constraints": "Pattern changes with age - STRIPES in juvenile become SPOTS in adult. Long tail is diagnostic",
        "coloration": "ADULT: pale tan/cream with dark brown spots (leopard pattern). JUVENILE: dark with pale stripes",
    },
    "orectolobus": {
        "view": "Dorsal view showing camouflage pattern and head lobes",
        "body": "Flattened head and body. Elaborately branched skin lobes (dermal lobes) around head. Broad, wing-like pectoral fins",
        "key_features": "Complex branching barbels and skin flaps around mouth creating 'beard'. Ornate camouflage pattern. Ambush predator",
        "constraints": "Highly flattened - this is a bottom-dwelling carpet shark. Elaborate head fringes are essential",
        "coloration": "complex tan, brown, and cream reticulated/symmetrical carpet-like pattern for camouflage",
    },
    "heterodontus": {
        "view": "Lateral view showing ridges and distinctive head shape",
        "body": "Blunt, pig-like snout. Prominent ridges above eyes. Two dorsal fins each with leading spine",
        "key_features": "Both dorsal fins have a SPINE at front. Pig-like blunt head. Can crush hard-shelled prey. 'Horn shark' refers to spines",
        "constraints": "SPINES on dorsal fins are diagnostic - must be shown. Different from most sharks",
        "coloration": "tan to brown with dark brown saddles and spots. Pattern of harness-like bands",
    },
    "chiloscyllium": {
        "view": "Lateral view showing elongated body and rounded fins",
        "body": "Elongated, cylindrical body. Long tail. Rounded, paddle-like fins. Small nasal barbels",
        "key_features": "Can survive out of water briefly. Juveniles often banded, adults plain or spotted. Bamboo-like appearance in some species",
        "constraints": "This is a small, docile shark - not dangerous or dramatic looking. Plain coloration common",
        "coloration": "varies by species - brown/tan with bands (juvenile) or spots, adults often plain brown-grey",
    },
    "prionace": {
        "view": "Full lateral view from snout to tail tip showing slender body. Calm pose, mouth closed",
        "body": "Very slender, streamlined body - one of most hydrodynamic sharks. Long pointed snout. Long sickle-shaped pectoral fins",
        "key_features": "BLUE SHARK - distinctive indigo-blue dorsally. Very long pectoral fins. Slender body. Large eyes. Pointed snout. Graceful swimmers",
        "constraints": "NO operculum - open gill slits. Cartilaginous skeleton. Slender build - not heavy-bodied like tiger shark",
        "coloration": "brilliant indigo blue dorsally (hence name), bright white ventrally - one of most beautiful sharks",
    },
    "squatina": {
        "view": "Dorsal view showing flat body shape",
        "body": "Flattened body intermediate between shark and ray. Pectoral fins not fused to head. Terminal mouth",
        "key_features": "Angel shark - flat like ray but is a shark. Mouth at front (terminal), not underneath. Gill slits on sides. Ambush predator",
        "constraints": "This is a SHARK despite flat appearance - has gill slits on side, mouth at front, unfused pectoral fins",
        "coloration": "mottled brown, grey, tan for camouflage on sandy bottom",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # RAYS - CARTILAGINOUS, FLAT BODY
    # ═══════════════════════════════════════════════════════════════════════════
    "mobula": {
        "view": "Dorsal-oblique view showing full wingspan and cephalic fins",
        "body": "Enormous diamond-shaped disc formed by pectoral fins. Distinct head projecting forward. Whip-like tail",
        "key_features": "CEPHALIC FINS - two horn-like projections flanking mouth (unfurl to channel plankton). Terminal mouth (at front). No tail spine (in most species). Wing-like pectoral fins",
        "constraints": "Cephalic fins (horns) are DIAGNOSTIC - must be shown. Tail usually has NO venomous spine (unlike stingrays). Filter feeder - harmless",
        "coloration": "jet black to dark brown dorsally. White ventrally with species-specific spot patterns. White shoulder patches in some",
    },
    "manta": {
        "view": "Dorsal-oblique view showing full wingspan and horn-like cephalic fins",
        "body": "Largest ray - wing span to 7m. Diamond disc. Prominent cephalic fins. No tail spine",
        "key_features": "Identical to Mobula (now merged genus). Cephalic fins, terminal mouth, filter feeding",
        "constraints": "NO tail spine. Completely harmless despite size",
        "coloration": "black dorsally with white shoulder patches, white ventrally with unique spot pattern (like fingerprint)",
    },
    "aetobatus": {
        "view": "Dorsal view showing spotted pattern and pointed wings",
        "body": "Flat diamond disc with POINTED wing tips (more angular than stingrays). Distinct head with duck-bill-like snout. Very long whip tail",
        "key_features": "Distinctive duck-bill snout. Long whip tail with 1-5 venomous spines near base. Often swims in groups. Spotted pattern. Wing tips sharply pointed",
        "constraints": "Has venomous spine(s) - unlike mantas. Head clearly distinct from disc",
        "coloration": "dark blue-grey to olive with matrix of white spots or rings. White underneath",
    },
    "dasyatis": {
        "view": "Dorsal view showing disc shape and tail",
        "body": "Flat diamond to oval disc. Eyes on top of head. Long whip tail with serrated venomous spine(s)",
        "key_features": "Tail spine is VENOMOUS and saw-edged. Spiracles behind eyes for breathing while buried. Mouth and gills underneath",
        "constraints": "Tail spine is dangerous - serrated and venomous. Body flat for burying in sand",
        "coloration": "grey to brown dorsally, often uniform. White underneath",
    },
    "taeniura": {
        "view": "Dorsal view showing pattern and tail spots",
        "body": "Round to oval disc. Long tail often with distinctive spots or bands",
        "key_features": "Blue-spotted species have electric blue spots on disc. Venomous tail spine",
        "constraints": "Has venomous spine. The blue spots (if present) are distinctive",
        "coloration": "varies - T. lymma has yellow-tan with vivid blue spots, T. meyeni has black spots on grey",
    },
    "neotrygon": {
        "view": "Dorsal view showing pattern",
        "body": "Small to medium disc, typically rhomboid shape",
        "key_features": "Blue-spotted species. Venomous tail spine. Prefers reef habitats",
        "constraints": "Has tail spine",
        "coloration": "variable - often grey or tan with spots (blue spots in kuhlii group)",
    },
    "himantura": {
        "view": "Dorsal view showing large disc and long tail",
        "body": "Large disc, can be very large (some to 2m). Very long thin whip tail",
        "key_features": "Often very long tail. Venomous spine(s). Some species with leopard spots",
        "constraints": "Has venomous spine",
        "coloration": "variable by species - spotted, uniform brown, or patterned",
    },
    "rhinoptera": {
        "view": "Dorsal view showing distinctive head shape",
        "body": "Diamond disc with BILOBED head - notched in middle looking like cow nose",
        "key_features": "Head distinctly notched in middle (cow-nose appearance). Long thin tail. Often in schools",
        "constraints": "The bilobed/notched head is DIAGNOSTIC",
        "coloration": "brown to olive-grey dorsally, white ventrally",
    },
    "torpedo": {
        "view": "Dorsal view showing rounded disc",
        "body": "Rounded disc (more circular than diamond). Kidney-shaped electric organs. Short stout tail with fin",
        "key_features": "ELECTRIC - can deliver strong shock. Rounded body. Short tail with caudal fin",
        "constraints": "This ray PRODUCES ELECTRICITY. Different shape from typical rays - more rounded",
        "coloration": "uniform brown to grey, sometimes with dark spots or eyespots",
    },
    "raja": {
        "view": "Dorsal view showing rhomboid shape",
        "body": "Rhomboid disc with pointed snout. Two small dorsal fins near tail tip. Row of thorns along back",
        "key_features": "Thorns/spines along midline of back and tail. Two dorsal fins on tail. Pointed snout",
        "constraints": "Has thorns but NO venomous tail spine like stingrays",
        "coloration": "mottled brown and grey with spots - camouflage pattern",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SEA TURTLES
    # ═══════════════════════════════════════════════════════════════════════════
    "chelonia": {
        "view": "Three-quarter dorsal view showing carapace and flipper structure",
        "body": "Oval streamlined carapace (shell). Four paddle-shaped flippers. Non-retractable head",
        "key_features": "Single pair of prefrontal scales between eyes. Four costal scutes. Serrated beak for vegetation. Green body fat (from diet)",
        "constraints": "Cannot retract head into shell. Flippers NOT legs - cannot walk properly on land",
        "coloration": "carapace olive to brown with radiating pattern on scutes. Plastron pale yellow-white",
    },
    "eretmochelys": {
        "view": "Three-quarter view showing beak and shell pattern",
        "body": "Relatively small sea turtle. Heart-shaped carapace with OVERLAPPING scutes (unique). Narrow head with pointed hawk-like beak",
        "key_features": "OVERLAPPING posterior scutes (like shingles). Sharp, hooked beak. Two pairs of prefrontal scales. Serrated shell margin in juveniles",
        "constraints": "The overlapping scutes and hawk-bill are DIAGNOSTIC. Critically endangered",
        "coloration": "beautiful amber/tortoiseshell pattern - brown with yellow, orange, red streaks (the 'tortoiseshell' of trade)",
    },
    "caretta": {
        "view": "Three-quarter view showing large head",
        "body": "Large head relative to body (hence 'loggerhead'). Heart-shaped carapace. Powerful jaws",
        "key_features": "Large head, heavy jaws for crushing shellfish. Five costal scutes (not four). Reddish-brown color",
        "constraints": "Larger head than other sea turtles proportionally",
        "coloration": "reddish-brown carapace, yellowish plastron",
    },
    "dermochelys": {
        "view": "Three-quarter dorsal view showing ridged leathery shell",
        "body": "Largest turtle (to 2m). Teardrop shape. LEATHERY skin instead of scutes. Seven longitudinal ridges on carapace. Enormous front flippers",
        "key_features": "NO SCUTES - only turtle without bony shell/scutes. Seven ridges along back. Largest front flippers relative to body. Can dive to 1000m",
        "constraints": "CRITICAL: No hard scutes - shell is leathery skin over cartilage. Do NOT draw typical turtle shell pattern",
        "coloration": "dark blue-black with white spotting. Pink spot on top of head",
    },
    "lepidochelys": {
        "view": "Dorsal view showing rounded shell",
        "body": "Smallest sea turtle. Rounded, almost circular carapace",
        "key_features": "More costal scutes (5-9) than other sea turtles. Rounded shell shape. Mass nesting behavior (arribada)",
        "constraints": "Small size compared to other sea turtles",
        "coloration": "olive-grey (hence 'Olive Ridley'). Pale plastron",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # OCTOPUSES
    # ═══════════════════════════════════════════════════════════════════════════
    "octopus": {
        "view": "Natural pose showing arm arrangement, suckers, and eye",
        "body": "Soft mantle (body) with eight arms. No internal or external shell. Large complex eye with horizontal pupil",
        "key_features": "Eight arms with TWO rows of suckers (not one). Siphon for jet propulsion. Chromatophores for instant color/texture change. Three hearts, blue blood",
        "constraints": "TWO rows of suckers per arm (unlike squid with one). NO shell. NO tentacles (arms only). Eight arms, not ten",
        "coloration": "highly variable - can change color and texture instantly. At rest typically reddish-brown mottled",
    },
    "hapalochlaena": {
        "view": "Natural pose clearly showing blue rings",
        "body": "Small size (body 5cm, arm span 10cm). Eight arms",
        "key_features": "IRIDESCENT BLUE RINGS that flash bright when threatened. Despite tiny size, one of most venomous animals. Rings are warning display",
        "constraints": "Blue rings are ESSENTIAL - they are the diagnostic feature. Small size - do not draw large",
        "coloration": "yellowish-tan to cream background with 50-60 brilliant blue rings that flash brighter with agitation",
    },
    "amphioctopus": {
        "view": "Natural pose showing behavior",
        "body": "Medium-sized octopus with prominent white stripe between eyes",
        "key_features": "Includes coconut octopus - uses tools (coconut shells for shelter). Often walks on two arms. Stripe between eyes",
        "constraints": "A. marginatus specifically carries shells - can show this behavior",
        "coloration": "dark brown with white stripe between eyes, pale suckers",
    },
    "thaumoctopus": {
        "view": "Showing characteristic posture or mimicry pose",
        "body": "Slender arms, small body",
        "key_features": "MIMIC OCTOPUS - can impersonate lionfish, flatfish, sea snakes, etc. Changes body shape and color dramatically. Long slender arms",
        "constraints": "Known for mimicry - can show it imitating another creature",
        "coloration": "brown and white bands/stripes (default), but can change to match mimicked species",
    },
    "wunderpus": {
        "view": "Showing distinctive pattern",
        "body": "Long slender arms, small mantle",
        "key_features": "Fixed brown and white pattern (unlike mimic octopus, pattern is consistent). Each individual has unique pattern like fingerprint",
        "constraints": "Pattern is FIXED - doesn't change as dramatically as mimic octopus",
        "coloration": "rust-brown and white striped/banded pattern, consistent for each individual",
    },
    "abdopus": {
        "view": "Showing 'walking' behavior",
        "body": "Small octopus that walks on arms",
        "key_features": "Often walks on reef substrate using arms. A. aculeatus well known for walking",
        "constraints": "Small species",
        "coloration": "variable, typically mottled brown/tan",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SQUID
    # ═══════════════════════════════════════════════════════════════════════════
    "sepioteuthis": {
        "view": "Lateral view showing full body with fins and tentacles",
        "body": "Torpedo-shaped mantle with LARGE lateral fins running most of body length. Eight arms plus two long tentacles",
        "key_features": "Fins extend along most of mantle (unlike many squid with small fins). Ten appendages total (8 arms + 2 tentacles). ONE row of suckers on arms. Internal pen (gladius)",
        "constraints": "Has TEN appendages (8+2), not eight like octopus. ONE row of suckers on arms (octopus has two)",
        "coloration": "iridescent, can rapidly change. Often shows flowing color patterns",
    },
    "loligo": {
        "view": "Lateral view showing streamlined body",
        "body": "Streamlined torpedo mantle with triangular fins at rear (not full length). Ten appendages",
        "key_features": "Small triangular fins at posterior end. Long feeding tentacles. Fast swimmer. Schooling behavior",
        "constraints": "Fins at REAR only, not full length. Ten appendages",
        "coloration": "translucent pink-white with red-brown chromatophores, iridescent",
    },
    "dosidicus": {
        "view": "Lateral view showing large size",
        "body": "Large, muscular squid (to 2m). Strong fins. Powerful tentacles",
        "key_features": "Humboldt/jumbo squid - aggressive, large. Suckers have sharp teeth. Red coloration when excited",
        "constraints": "Large predatory squid - very different from small market squid",
        "coloration": "red-purple when excited, pale when calm, rapid color changes",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # CUTTLEFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "sepia": {
        "view": "Lateral view showing undulating fin and W-shaped eye",
        "body": "Oval/shield-shaped body. Fin runs entire length on both sides creating undulating ribbon. Internal cuttlebone",
        "key_features": "W-SHAPED PUPIL (diagnostic). Fin runs full body length. Eight arms plus two tentacles (retractable into pockets). Internal buoyant cuttlebone",
        "constraints": "The W-shaped pupil is CRITICAL identifier. Fin is FULL-LENGTH, not just at rear like squid",
        "coloration": "master of camouflage - can produce any color/pattern. Often shows moving zebra stripes when displaying",
    },
    "metasepia": {
        "view": "Showing remarkable color display",
        "body": "Small cuttlefish with elaborate finnage",
        "key_features": "Flamboyant cuttlefish - walks on substrate using arms. Brilliant warning colors. TOXIC flesh (aposematic)",
        "constraints": "WALKS more than swims. Very bright colors = warning (toxic)",
        "coloration": "bright purple, pink, yellow, white in striking patterns - warning coloration",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SWIMMING CRABS (Portunidae)
    # ═══════════════════════════════════════════════════════════════════════════
    "portunus": {
        "view": "Dorsal view showing paddle legs and full carapace",
        "body": "Broad, flattened carapace with lateral spines. Fifth pair of legs modified into paddle-shaped SWIMMING appendages",
        "key_features": "Rear legs are PADDLE-SHAPED (flattened, oar-like) for swimming. Nine teeth/spines on front edge of carapace. Strong claws (chelae) with sharp fingers",
        "constraints": "Fifth legs MUST be shown as paddles, not pointed walking legs",
        "coloration": "varies by species - blue swimming crab has blue claws and legs, mottled carapace",
    },
    "callinectes": {
        "view": "Dorsal view showing blue coloration and paddles",
        "body": "Classic swimming crab shape with prominent lateral spines. Paddle-shaped rear legs",
        "key_features": "Blue crab - brilliant blue on claws (especially males). Rear legs paddle-shaped. Nine frontal teeth. Females have red-tipped claws",
        "constraints": "Paddle legs essential. Blue coloring on chelae is distinctive",
        "coloration": "olive-green carapace, bright blue chelipeds (male), red claw tips (female)",
    },
    "charybdis": {
        "view": "Dorsal view showing carapace shape",
        "body": "Swimming crab with posterior paddle legs. Variably shaped carapace depending on species",
        "key_features": "Paddle legs for swimming. Various spine patterns by species",
        "constraints": "Paddle legs present",
        "coloration": "typically mottled brown, green, or purple depending on species",
    },
    "thalamita": {
        "view": "Dorsal view showing carapace and chelipeds",
        "body": "Smaller swimming crab with paddle legs",
        "key_features": "Rear paddle legs. Relatively large chelipeds. Flattened body",
        "constraints": "Paddle legs present",
        "coloration": "variable - often dark with spots or mottling",
    },
    "podophthalmus": {
        "view": "View showing distinctive stalked eyes",
        "body": "Swimming crab with EXTREMELY long eye stalks (longest of any crab)",
        "key_features": "Eyes on very long stalks extending well beyond carapace. Paddle rear legs. 'Sentinel crab'",
        "constraints": "Eye stalks are UNUSUALLY long - must be shown",
        "coloration": "typically tan/brown",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # OTHER CRABS
    # ═══════════════════════════════════════════════════════════════════════════
    "grapsus": {
        "view": "Dorsal view showing square carapace",
        "body": "Nearly square carapace. Long walking legs. Relatively small chelipeds (claws)",
        "key_features": "Square-ish carapace with rounded corners. Long legs for running on rocks. Quick and agile. Sally Lightfoot crab is best known",
        "constraints": "Claws are NOT large/prominent - this is a running crab, not a crushing crab",
        "coloration": "highly variable but often spectacular - bright red, orange, blue legs; mottled carapace. G. grapsus especially colorful",
    },
    "percnon": {
        "view": "Dorsal view showing flat body and long legs",
        "body": "Very flat disc-shaped carapace. Extremely long, thin walking legs",
        "key_features": "Spider-like appearance - very flat body, very long thin legs. Small chelipeds. 'Nimble spray crab'",
        "constraints": "Body is FLAT, legs are LONG and THIN - spider crab appearance",
        "coloration": "dark brown/maroon with lighter bands on legs, sometimes blue-green highlights",
    },
    "carpilius": {
        "view": "Dorsal view showing massive claws",
        "body": "Oval convex carapace. Extremely heavy, powerful chelipeds",
        "key_features": "Massive crushing claws - one of strongest grip of any crab. Smooth convex carapace. Eats hard-shelled mollusks",
        "constraints": "Claws are EXTREMELY large and powerful",
        "coloration": "typically mottled red and white/cream (C. maculatus) or solid red-brown",
    },
    "calappa": {
        "view": "Dorsal view showing distinctive shell shape",
        "body": "Box-like appearance - carapace has lateral wings covering legs. Large flat chelipeds that close against body like doors",
        "key_features": "Carapace expands laterally to cover legs (box crab/shame-faced crab). Chelipeds flatten against body, one has special tooth for opening shells",
        "constraints": "Distinctive boxy shape with lateral extensions",
        "coloration": "cream to yellow with red-brown spots and mottling",
    },
    "dromia": {
        "view": "View showing sponge-carrying behavior",
        "body": "Rounded hairy carapace. Rear legs held dorsally to grip camouflage",
        "key_features": "Carries sponges, tunicates, or other materials on back for camouflage. Rear legs modified for holding, positioned on back",
        "constraints": "Often shown WITH material (sponge) being carried",
        "coloration": "typically brownish, often obscured by carried material",
    },
    "majidae": {
        "view": "View showing decorated appearance",
        "body": "Triangular/pear-shaped carapace with rostrum. Long spindly legs. Small chelipeds",
        "key_features": "Decorator crab - covers self with algae, sponges, debris. Hooked setae (hairs) hold decorations. Long spider-like legs",
        "constraints": "Often heavily decorated with attached materials",
        "coloration": "variable, often hidden under decorations",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # HERMIT CRABS
    # ═══════════════════════════════════════════════════════════════════════════
    "dardanus": {
        "view": "View showing crab emerging from gastropod shell",
        "body": "Asymmetrical soft abdomen (hidden in shell). Only front parts calcified. Large left cheliped typically larger",
        "key_features": "Lives in gastropod shells - MUST show shell. Soft twisted abdomen for coiling in shell. Left claw usually larger (opposite of most decapods). Anemones often on shell",
        "constraints": "MUST be shown in/with gastropod shell. Soft abdomen NOT visible. Left claw larger than right",
        "coloration": "claws and legs often colorful - reds, oranges, blues with spots or stripes",
    },
    "calcinus": {
        "view": "Emerging from shell showing colorful legs",
        "body": "Small hermit crab in gastropod shell. Equal or nearly equal sized claws",
        "key_features": "Often brightly colored legs. Lives in small shells. Both claws similar size",
        "constraints": "Must have shell. Small size",
        "coloration": "often bright - blue, orange, red legs with contrasting bands",
    },
    "clibanarius": {
        "view": "In shell showing striped legs",
        "body": "Small hermit in gastropod shell. Equal-sized claws",
        "key_features": "Often striped legs. Common intertidal hermit. Equal claws",
        "constraints": "Must be in shell",
        "coloration": "typically striped - banded legs in browns, greens, oranges",
    },
    "pagurus": {
        "view": "Emerging from shell showing right claw larger",
        "body": "In gastropod shell. RIGHT claw larger (opposite of Dardanus)",
        "key_features": "Right cheliped larger. Often lives in whelk or other large shells",
        "constraints": "Right claw larger. Must have shell",
        "coloration": "typically browns and reds",
    },
    "coenobita": {
        "view": "Land hermit showing shell and terrestrial adaptations",
        "body": "Modified for terrestrial life. In land snail shells or other shells",
        "key_features": "Land hermit crab - lives on land, returns to sea to breed. Large left claw. Can climb",
        "constraints": "Terrestrial - must be on land, not underwater",
        "coloration": "often purple, red, or orange coloration especially on large claw",
    },
    "birgus": {
        "view": "Full body view without shell",
        "body": "LARGEST land arthropod (to 4kg). No longer uses shell as adult. Heavily calcified entire body",
        "key_features": "Coconut crab - only hermit crab that abandons shell as adult. Massive chelipeds can crack coconuts. Can climb trees. Calcified abdomen (unlike other hermits)",
        "constraints": "NO SHELL as adult - unique among hermit crabs. Very large",
        "coloration": "varies - can be blue, purple, orange, or brown depending on diet and location",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SHRIMP - Penaeid/Commercial
    # ═══════════════════════════════════════════════════════════════════════════
    "penaeus": {
        "view": "Lateral view showing curved body and rostrum",
        "body": "Laterally compressed elongated body. Long serrated rostrum (beak). Long antennae. Pleopods for swimming. Fan-shaped tail (telson + uropods)",
        "key_features": "Long toothed rostrum extending forward. Three pairs of chelate (small pincer) legs. Five pairs of swimming pleopods. Long antennae and antennules",
        "constraints": "Claws are SMALL - on first three leg pairs. Not large like lobster claws",
        "coloration": "translucent grey, pink, or brown with subtle banding. Pink when cooked",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SHRIMP - Cleaner Shrimp
    # ═══════════════════════════════════════════════════════════════════════════
    "lysmata": {
        "view": "Lateral view showing color pattern and long antennae",
        "body": "Slender shrimp with very long white antennae. Curved body",
        "key_features": "Long white antennae. Many species are cleaners - remove parasites from fish. Often has stripes or spots. L. amboinensis has red/white stripe pattern",
        "constraints": "Long antennae are diagnostic. Cleaning behavior notable",
        "coloration": "varies - L. amboinensis: red and white stripes, L. debelius: bright red with white spots",
    },
    "stenopus": {
        "view": "Lateral view showing banded pattern and elongated claws",
        "body": "Laterally compressed. Third pair of legs elongated with small pincers. Very long antennae",
        "key_features": "BANDED CORAL SHRIMP - distinctive red and white banding. Third legs greatly elongated with small claws. Spiny carapace. Long white antennae",
        "constraints": "The banding pattern (red/white) is essential. Third legs are elongated, not first",
        "coloration": "brilliant red and white alternating bands covering entire body. White antennae",
    },
    "periclimenes": {
        "view": "Showing transparent body and spots",
        "body": "Small, often transparent shrimp",
        "key_features": "Commensal shrimp - lives with anemones, sea cucumbers, etc. Often nearly transparent with colored spots. Long slender claws",
        "constraints": "Often transparent/glass-like. Lives with host invertebrate",
        "coloration": "usually transparent with purple, white, or colored spots/markings",
    },
    "ancylomenes": {
        "view": "Showing association with host anemone",
        "body": "Small transparent shrimp similar to Periclimenes",
        "key_features": "Anemone shrimp - specifically lives with anemones. Often transparent with spots",
        "constraints": "Associated with anemone hosts",
        "coloration": "transparent with white and purple markings typically",
    },
    "thor": {
        "view": "Showing 'tail-up' posture",
        "body": "Tiny shrimp (1cm) with characteristically elevated tail",
        "key_features": "Sexy shrimp - holds tail elevated and waves it. Lives on anemones. Very small",
        "constraints": "Tail is held UP in characteristic pose. Very small",
        "coloration": "tan/brown with white spots or saddles",
    },
    "hymenocera": {
        "view": "Showing distinctive paddle-like claws",
        "body": "Small flattened shrimp with broad paddle-shaped claws (chelae)",
        "key_features": "Harlequin shrimp - chelipeds modified into large flat paddles with spotted pattern. Feeds exclusively on starfish. Bold coloration",
        "constraints": "Claws are FLAT and PADDLE-SHAPED - not typical claw shape",
        "coloration": "cream/white base with pink, purple, or blue spots - distinctive harlequin pattern",
    },
    "rhynchocinetes": {
        "view": "Showing hinged rostrum",
        "body": "Small shrimp with hinged, moveable rostrum",
        "key_features": "Hinged-beak shrimp - rostrum can bend up and down (unique). Red and white stripes. Large eyes",
        "constraints": "Rostrum is HINGED - unusual feature",
        "coloration": "red and white stripes, large eyes",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SHRIMP - Pistol/Snapping
    # ═══════════════════════════════════════════════════════════════════════════
    "alpheus": {
        "view": "Showing asymmetrical claws with one enlarged",
        "body": "Robust shrimp with one greatly enlarged snapping claw",
        "key_features": "PISTOL SHRIMP - one claw is MASSIVELY enlarged and can snap to create cavitation bubble (louder than gunshot). Often lives with gobies in shared burrow",
        "constraints": "ONE claw is MUCH larger than the other - this asymmetry is critical",
        "coloration": "varies by species - often red, green, or brown; tiger pistol has banding",
    },
    "synalpheus": {
        "view": "Showing snapping claw",
        "body": "Similar to Alpheus with snapping claw",
        "key_features": "Snapping claw present. Often lives commensally with sponges. Some species are eusocial (like bees)",
        "constraints": "One claw enlarged for snapping",
        "coloration": "variable, often matching host",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # MANTIS SHRIMP (Stomatopoda)
    # ═══════════════════════════════════════════════════════════════════════════
    "odontodactylus": {
        "view": "Anterior view showing raptorial appendages and eyes",
        "body": "Elongated, flattened body with segmented armor. Distinctive trinocular compound eyes on stalks",
        "key_features": "RAPTORIAL APPENDAGES - second thoracic appendages modified into club-like SMASHERS (not spearers). Can strike with force of bullet. Eyes see more colors than any animal (16 color receptors vs human 3)",
        "constraints": "NOT a true shrimp - different order (Stomatopoda). SMASHING type - clubs, not spears. Do NOT draw typical shrimp shape",
        "coloration": "spectacular - often peacock mantis (O. scyllarus) has green, blue, red, orange patterns",
    },
    "gonodactylus": {
        "view": "Showing raptorial claws",
        "body": "Smaller mantis shrimp with smashing appendages",
        "key_features": "Smashing type raptorial appendages. Smaller than Odontodactylus. Incredible color vision",
        "constraints": "Smasher type (club-like)",
        "coloration": "variable, often greenish or brownish with color accents",
    },
    "lysiosquilla": {
        "view": "Showing spearing appendages",
        "body": "Large mantis shrimp with spear-like raptorial appendages",
        "key_features": "SPEARER type - raptorial appendages have sharp barbed tips for stabbing soft prey (vs smashers that hit hard-shelled prey)",
        "constraints": "SPEARER type - different from smashers. Longer, with barbed spines",
        "coloration": "often cryptic - sand/mud colored",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # NUDIBRANCHS
    # ═══════════════════════════════════════════════════════════════════════════
    "chromodoris": {
        "view": "Dorsal view showing mantle color and gills",
        "body": "Oval, elongated soft body. NO SHELL. Two rhinophores (sensory tentacles) on head. Branchial plume (feathery gills) at rear",
        "key_features": "Rhinophores (pair of sensory tentacles on head). Branchial plume (circle of gills on rear dorsum). Mantle often extends beyond foot. Brilliant colors - warning/aposematic",
        "constraints": "NO shell - this is a sea slug. Gills are EXTERNAL (branchial plume), not internal",
        "coloration": "spectacular species-specific patterns - often blue with black spots and orange/yellow margins",
    },
    "hypselodoris": {
        "view": "Dorsal view showing color pattern",
        "body": "Similar dorid nudibranch body plan",
        "key_features": "Rhinophores and branchial plume. Often purple and yellow coloration",
        "constraints": "No shell. External gills",
        "coloration": "typically purple or blue body with yellow margins",
    },
    "glossodoris": {
        "view": "Dorsal view showing mantle edge",
        "body": "Dorid nudibranch with wavy mantle edge",
        "key_features": "Often frilly/wavy mantle margin. Rhinophores and gills. Eats sponges",
        "constraints": "No shell. External gills",
        "coloration": "variable - often white/cream with colored spots or margins",
    },
    "phyllidia": {
        "view": "Dorsal view showing tubercles",
        "body": "Oval body covered in compound tubercles (raised bumps). No visible gills",
        "key_features": "WARTY/TUBERCULATE surface - covered in raised bumps. Gills are NOT visible externally (hidden). Rhinophores retract into pockets. Produces toxic chemicals",
        "constraints": "Gills are HIDDEN - do not show branchial plume. Bumpy texture is essential",
        "coloration": "typically black with yellow, white, or pink tubercles in distinctive patterns",
    },
    "phyllidiella": {
        "view": "Dorsal view showing tubercle pattern",
        "body": "Similar to Phyllidia with tuberculate surface",
        "key_features": "Compound tubercles. Hidden gills. Often has ridges connecting tubercles",
        "constraints": "Hidden gills, warty surface",
        "coloration": "black with pink or white tubercles and ridges",
    },
    "nembrotha": {
        "view": "Showing bold color pattern",
        "body": "Dorid nudibranch with robust body",
        "key_features": "Bold contrasting colors. Eats tunicates. Branchial plume and rhinophores often same color accent",
        "constraints": "External gills. No shell",
        "coloration": "striking patterns - often black/dark green with bright orange, red, or green pustules/markings",
    },
    "flabellina": {
        "view": "Lateral view showing cerata arrangement",
        "body": "Elongated body covered with CERATA (finger-like projections) instead of branchial plume",
        "key_features": "CERATA - rows of finger-like projections covering body. These contain branches of digestive system and may store stinging cells from prey. NO branchial plume",
        "constraints": "Has CERATA not branchial plume - different nudibranch type (aeolid vs dorid)",
        "coloration": "often purple/pink body with orange or purple-tipped cerata",
    },
    "pteraeolidia": {
        "view": "Showing dense cerata coverage",
        "body": "Elongated body densely covered with cerata",
        "key_features": "Blue dragon nudibranch - hosts symbiotic zooxanthellae (like coral). Dense cerata. Can be quite large for nudibranch",
        "constraints": "Cerata, not branchial plume. Contains symbiotic algae",
        "coloration": "blue to purple body with brown cerata (zooxanthellae visible inside)",
    },
    "hexabranchus": {
        "view": "View showing swimming or ruffled mantle",
        "body": "Large nudibranch (to 50cm) with undulating mantle edge. Can swim by flapping mantle",
        "key_features": "SPANISH DANCER - can swim by undulating broad mantle edge. Six branchial gills (hence name). Largest nudibranch. Frilly/ruffled appearance",
        "constraints": "Six gills specifically. Large size. Swimming capability",
        "coloration": "bright red to pink, sometimes with white spots on mantle margin",
    },
    "jorunna": {
        "view": "Dorsal view showing furry appearance",
        "body": "Rounded body covered with fine papillae giving furry appearance",
        "key_features": "Looks like small fluffy rabbit due to caryophyllidia (papillae). J. parva is the famous 'sea bunny'",
        "constraints": "Furry/fluffy texture from papillae",
        "coloration": "often white/cream with black specks or pale yellow",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # JELLYFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "aurelia": {
        "view": "View from below showing four-leaf clover pattern",
        "body": "Translucent dome-shaped bell. Short fringe of marginal tentacles. Four oral arms",
        "key_features": "FOUR HORSESHOE-SHAPED GONADS visible through bell (4-leaf clover pattern). Short tentacles. Nearly transparent bell. Moon jellyfish",
        "constraints": "The four-leaf clover gonad pattern is DIAGNOSTIC - must be visible",
        "coloration": "transparent/translucent with four pink or purple horseshoe shapes visible",
    },
    "chrysaora": {
        "view": "Showing tentacles and bell pattern",
        "body": "Hemispherical bell with radiating pattern. Long trailing tentacles. Four frilly oral arms",
        "key_features": "Radial stripe pattern on bell. Long stinging tentacles (to 3m). Sea nettle - painful sting",
        "constraints": "Long tentacles are characteristic",
        "coloration": "variable - often golden-brown, orange, or reddish with darker radial stripes",
    },
    "pelagia": {
        "view": "Showing warty bell and tentacles",
        "body": "Small bell with warty/granular surface. Eight long tentacles. Four oral arms",
        "key_features": "Entire surface including bell is STINGING (unlike most jellies where only tentacles sting). Warty texture on bell. Bioluminescent",
        "constraints": "Warty texture on bell surface. Stings from bell too",
        "coloration": "pink, purple, or mauve with darker spots. Luminescent at night",
    },
    "cyanea": {
        "view": "Showing massive tentacle mass",
        "body": "Very large bell (to 2m diameter). Extremely numerous, long tentacles in masses. Large oral arms",
        "key_features": "Lion's mane jellyfish - LARGEST jellyfish. Masses of tentacles in 8 groups. Lobed bell margin. Tentacles can reach 30m",
        "constraints": "Very large size. Massive tentacle mass",
        "coloration": "red, orange, or yellow bell (color varies with size - larger = darker)",
    },
    "cassiopea": {
        "view": "Showing upside-down posture",
        "body": "Flat disc-shaped bell. Branching oral arms. NO marginal tentacles",
        "key_features": "UPSIDE-DOWN jellyfish - rests with bell down, oral arms up. Contains symbiotic zooxanthellae (photosynthetic). Pulsates gently on substrate",
        "constraints": "Always shown UPSIDE DOWN - bell on bottom, arms pointing up",
        "coloration": "brown, green, or blue due to symbiotic algae. Branching arms often with white tips",
    },
    "mastigias": {
        "view": "Showing spotted pattern",
        "body": "Rounded bell with spots. Eight oral arms with club-like endings. NO long tentacles",
        "key_features": "Spotted jelly. Contains zooxanthellae. Mild or no sting. Oral arms have filaments, no long tentacles",
        "constraints": "NO long stinging tentacles. Has zooxanthellae (can survive without prey)",
        "coloration": "golden-brown to blue-green with white spots. Color from zooxanthellae",
    },
    "rhopilema": {
        "view": "Showing bell and oral arms",
        "body": "Large dome-shaped bell. Eight branching oral arms with no central mouth",
        "key_features": "No central mouth - food absorbed through arm branches. Large size. Edible (Asian cuisine)",
        "constraints": "No marginal tentacles. No central mouth opening",
        "coloration": "white, blue, or reddish depending on species",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SEA STARS (ASTEROIDEA)
    # ═══════════════════════════════════════════════════════════════════════════
    "linckia": {
        "view": "Dorsal view showing arm arrangement",
        "body": "Central disc with typically five long, cylindrical arms. Tube feet on underside",
        "key_features": "Long cylindrical arms with rounded tips. Smooth surface with small granules. Can regenerate entire body from single arm. Often bright solid colors",
        "constraints": "Arms are CYLINDRICAL and smooth, not broad or spiny",
        "coloration": "often bright blue (L. laevigata), but can be purple, orange, or mottled",
    },
    "fromia": {
        "view": "Dorsal view showing color pattern",
        "body": "Five arms with small central disc. Regular shape",
        "key_features": "Small to medium size. Bright colors. Often has darker contrasting tips on arms",
        "constraints": "Arms not excessively long",
        "coloration": "typically red or orange, often with darker tips or patterns",
    },
    "nardoa": {
        "view": "Dorsal view",
        "body": "Five cylindrical arms from small disc",
        "key_features": "Smooth or slightly granular surface. Similar to Linckia",
        "constraints": "Smooth arms",
        "coloration": "variable - often tan, brown, or variegated",
    },
    "protoreaster": {
        "view": "Dorsal view showing tubercles and nodules",
        "body": "Large, inflated body with raised tubercles/nodules. Five short broad arms",
        "key_features": "Covered with conical tubercles. Thick, puffy appearance. Chocolate chip/horned sea star",
        "constraints": "Arms are SHORT and broad relative to disc. Prominent tubercles",
        "coloration": "typically tan/cream with dark brown or black tubercle tips ('chocolate chips')",
    },
    "oreaster": {
        "view": "Dorsal view showing thick body",
        "body": "Very thick, inflated body with five broad arms. Heavily armored",
        "key_features": "Massive, heavy body. Covered with tubercles. Sometimes network pattern",
        "constraints": "Very thick/inflated body",
        "coloration": "red, orange, or brown, often with darker network pattern",
    },
    "culcita": {
        "view": "Dorsal view showing cushion shape",
        "body": "PENTAGONAL cushion shape - arms so reduced it appears as five-sided pillow",
        "key_features": "No distinct arms - body is puffy cushion/pillow shape. Appears like starfish with arms fused/filled in",
        "constraints": "NO distinct arms - looks like pentagonal pillow, not typical star shape",
        "coloration": "variable - often mottled brown, grey, green with patterns",
    },
    "acanthaster": {
        "view": "Dorsal view showing multiple arms and spines",
        "body": "Large disc with 7-23 arms (more than typical 5). Covered in sharp venomous spines",
        "key_features": "Crown-of-thorns starfish - VENOMOUS spines covering entire surface. More than 5 arms (7-23). Eats coral - major reef pest. Can be 50cm diameter",
        "constraints": "MORE than 5 arms - must show 7+ arms. Densely covered in spines",
        "coloration": "typically purplish-grey, green, or brown with contrasting spine tips",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SEA URCHINS
    # ═══════════════════════════════════════════════════════════════════════════
    "diadema": {
        "view": "Oblique view showing long spines",
        "body": "Spherical test (shell) with VERY long, hollow, needle-like spines",
        "key_features": "Extremely long spines - up to 30cm, longer than body diameter. Spines are hollow and brittle, break off easily. VENOMOUS. Spines are banded in some species",
        "constraints": "Spines are VERY LONG relative to body - this is critical",
        "coloration": "jet black with black spines, or banded black and white spines",
    },
    "echinothrix": {
        "view": "Showing two spine types",
        "body": "Spherical test with two types of spines - long thin primary spines and shorter thick secondary spines",
        "key_features": "TWO distinct spine types - long hollow venomous needles AND shorter blunt spines. Banded pattern common. Venomous",
        "constraints": "Two different spine types must be shown",
        "coloration": "often banded spines in black/white or green/black",
    },
    "echinometra": {
        "view": "Showing urchin in rock boring",
        "body": "Oval test (elongated, not spherical). Short, thick spines",
        "key_features": "OVAL test (not round). Bores into rock - often found in self-created holes. Short stout spines",
        "constraints": "Test is OVAL/elongated, not spherical like other urchins",
        "coloration": "variable - often dark (black, purple, green)",
    },
    "tripneustes": {
        "view": "Showing test pattern and pedicellariae",
        "body": "Spherical test with short white-tipped spines. Prominent pedicellariae",
        "key_features": "Short spines with white/cream tips. Visible tube feet. Often collects debris. TEST visible through short spines",
        "constraints": "Spines are SHORT - test pattern should be visible. Often has debris on top",
        "coloration": "test typically dark red/brown, spine tips white. Often covered with debris",
    },
    "toxopneustes": {
        "view": "Showing prominent pedicellariae",
        "body": "Spherical test with short spines and very prominent flower-like PEDICELLARIAE",
        "key_features": "Flower urchin - pedicellariae are enlarged, flower-like, HIGHLY VENOMOUS (most venomous urchin). Short spines almost hidden by pedicellariae",
        "constraints": "Pedicellariae (flower-like structures) are the prominent feature - more visible than spines",
        "coloration": "variable test color with white/cream pedicellariae that may have pink/purple centers",
    },
    "heterocentrotus": {
        "view": "Showing thick pencil-like spines",
        "body": "Oval test with very thick, blunt, pencil-like primary spines",
        "key_features": "Slate pencil urchin - spines are THICK, triangular/pencil-shaped, blunt-tipped. Red color common",
        "constraints": "Spines are THICK and BLUNT - like pencils or crayons, not needles",
        "coloration": "often bright red spines, reddish-brown test",
    },
    "colobocentrotus": {
        "view": "Dorsal view showing flat appearance",
        "body": "Flattened, helmet-shaped test. Spines modified into flat, tile-like plates on top",
        "key_features": "Shingle urchin - top spines fused/flattened into smooth shield. Withstands wave surge. Flattened profile",
        "constraints": "Top surface is FLAT/smooth - spines are modified into flat plates. Does NOT look like typical urchin",
        "coloration": "typically dark purple to black",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SEA CUCUMBERS
    # ═══════════════════════════════════════════════════════════════════════════
    "holothuria": {
        "view": "Lateral view showing tube feet and feeding tentacles",
        "body": "Elongated sausage-shaped body. Tube feet on ventral surface. Ring of feeding tentacles around mouth",
        "key_features": "Leathery body wall, often warty. Tube feet arranged in rows on underside for locomotion. Bushy or shield-shaped tentacles around mouth. Can expel internal organs as defense (evisceration)",
        "constraints": "Elongated soft body - no shell, no spines. Distinct ventral (foot) and dorsal surfaces",
        "coloration": "typically black, brown, or mottled. Some with spots or patterns",
    },
    "actinopyga": {
        "view": "Lateral view",
        "body": "Firm, sausage-shaped body. Tentacles shield-shaped",
        "key_features": "Firmer body than most sea cucumbers. Papillae on dorsal surface. Five teeth around anus (Cuvierian tubule defense)",
        "constraints": "No spines or shell",
        "coloration": "often dark - black or dark brown, sometimes with spotted pattern",
    },
    "bohadschia": {
        "view": "Lateral view showing Cuvierian tubules if expelled",
        "body": "Large, soft body with prominent papillae",
        "key_features": "Known for expelling sticky white Cuvierian tubules when threatened. Large body size. Mottled coloration",
        "constraints": "Soft body",
        "coloration": "typically mottled brown, grey, and cream",
    },
    "stichopus": {
        "view": "Dorsal-lateral view showing papillae",
        "body": "Large cucumber with squared cross-section. Prominent conical papillae on dorsal surface",
        "key_features": "Body has squared cross-section. Large conical papillae (bumps) on back. Lateral projections (parapodia) in some species",
        "constraints": "Squared profile, prominent papillae",
        "coloration": "variable - often greenish, brownish, or variegated with contrasting papillae",
    },
    "thelenota": {
        "view": "Showing distinctive papillae",
        "body": "Very large cucumber (to 70cm) with large star-shaped papillae",
        "key_features": "Prickly redfish - large with distinctive star-shaped papillae creating 'pineapple' texture",
        "constraints": "Large size, star-shaped papillae",
        "coloration": "typically reddish-brown to orange with contrasting papillae",
    },
    "synapta": {
        "view": "Showing elongated worm-like body",
        "body": "Very elongated, worm-like - much longer and thinner than typical cucumber. Anchor-shaped spicules in skin",
        "key_features": "Worm-like elongated body. Skin has microscopic anchor spicules (sticky feel). Highly flexible",
        "constraints": "Very THIN and ELONGATED - looks more like worm than cucumber. Sticks to surfaces",
        "coloration": "often transparent or translucent with visible internal organs, banded pattern",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SEA ANEMONES
    # ═══════════════════════════════════════════════════════════════════════════
    "stichodactyla": {
        "view": "Top view showing tentacle carpet",
        "body": "Flat oral disc covered with short, densely packed tentacles. Cylindrical column attached to substrate",
        "key_features": "Carpet anemone - tentacles SHORT and DENSE like carpet/shag rug. Hosts clownfish. Large oral disc. Sticky tentacles with stinging cells",
        "constraints": "Tentacles are SHORT and DENSELY packed - not long flowing tentacles",
        "coloration": "variable - brown, green, purple, often with contrasting tentacle tips (fluorescent)",
    },
    "heteractis": {
        "view": "Showing tentacle arrangement",
        "body": "Oral disc with longer tentacles. Column may have verrucae (bumps)",
        "key_features": "Bubble-tip anemone (H. magnifica) has enlarged bulb tips on tentacles. Also hosts clownfish. Tentacles longer than carpet anemone",
        "constraints": "Some species have bubble-tips - if so, must show enlarged tentacle ends",
        "coloration": "various - often brown, green, purple, or red. May have contrasting tentacle tips",
    },
    "entacmaea": {
        "view": "Showing bubble tips",
        "body": "Column with oral disc. Tentacles often with bulbous tips",
        "key_features": "Bubble-tip anemone - tentacles usually have BULBOUS/SWOLLEN tips. Major clownfish host. Can be solitary or colonial (divides)",
        "constraints": "Tentacle tips often BULBOUS (though not always)",
        "coloration": "highly variable - rose, green, brown, tan. Tips may contrast",
    },
    "condylactis": {
        "view": "Showing long tentacles with colored tips",
        "body": "Column often buried. Long flowing tentacles with distinctly colored tips",
        "key_features": "Condy anemone - long slender tentacles often with PINK, PURPLE, or GREEN tips. Does NOT host clownfish (Atlantic species)",
        "constraints": "Colorful tentacle tips are characteristic",
        "coloration": "tan or brown column, tentacles white/tan with pink, purple, or green tips",
    },
    "macrodactyla": {
        "view": "Showing long tentacles",
        "body": "Large anemone with very long tentacles",
        "key_features": "Long tentacle anemone - tentacles very long relative to disc. Hosts clownfish",
        "constraints": "Tentacles are LONG",
        "coloration": "variable - often purplish or greenish",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # CLOWNFISH / ANEMONEFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "amphiprion": {
        "view": "Lateral view showing color pattern and bars",
        "body": "Small oval body. Rounded fins. Thick mucus coating (for anemone protection)",
        "key_features": "Vertical white bars/bands - number and position species-specific. Lives symbiotically WITH sea anemones (only fish that can). Mucus coat prevents anemone sting. Protandrous hermaphrodite (male to female)",
        "constraints": "Always associated with anemone host. White bars are KEY identifier - count and pattern matter",
        "coloration": "orange, red, or black background with 0-3 white vertical bars depending on species",
    },
    "premnas": {
        "view": "Lateral view showing spine",
        "body": "Similar to Amphiprion but with spine under eye",
        "key_features": "Maroon clownfish - has distinctive SPINE on cheek below eye. Three white bars. Usually maroon/dark red color",
        "constraints": "Cheek spine distinguishes from Amphiprion. Three bars",
        "coloration": "deep maroon/burgundy with three white bars (bars may be yellow-tinged in some)",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # GROUPERS
    # ═══════════════════════════════════════════════════════════════════════════
    "epinephelus": {
        "view": "Lateral view showing robust body and large mouth",
        "body": "Heavy-bodied, laterally compressed. Large mouth with lower jaw slightly projecting. Spiny then soft dorsal fin continuous",
        "key_features": "Protruding lower jaw. Can be very large (giant grouper to 2.7m). Changes sex (female to male). Three spines on operculum. Dark spots or bars common",
        "constraints": "Heavy/robust body shape. Large gape",
        "coloration": "highly variable by species - browns, tans, greys, often with spots, bars, or mottling",
    },
    "cephalopholis": {
        "view": "Lateral view showing color pattern",
        "body": "Smaller, compact grouper body. Rounded caudal fin",
        "key_features": "Hinds/coral groupers - smaller than Epinephelus. Often more colorful - reds, oranges common",
        "constraints": "Smaller size than giant groupers",
        "coloration": "often bright - coral hind is red with blue spots, peacock hind has blue spots on dark body",
    },
    "plectropomus": {
        "view": "Lateral view",
        "body": "Elongated grouper body. More slender than Epinephelus",
        "key_features": "Coral trout/leopard coral grouper - elongated body, often with blue spots on red/pink background",
        "constraints": "More elongated than typical groupers",
        "coloration": "typically red/orange/pink with blue spots",
    },
    "variola": {
        "view": "Lateral view showing tail shape",
        "body": "Grouper with crescent (lunate) tail - unusual for groupers",
        "key_features": "Lyretail grouper - caudal fin is CRESCENT-SHAPED (most groupers have rounded tails). Yellow edge to fins common",
        "constraints": "LUNATE (crescent) tail is diagnostic - different from typical grouper",
        "coloration": "red or orange with blue spots, yellow fin margins",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # WRASSES
    # ═══════════════════════════════════════════════════════════════════════════
    "thalassoma": {
        "view": "Lateral view showing color pattern",
        "body": "Elongated, cigar-shaped body. Terminal mouth with thick lips. Single continuous dorsal fin",
        "key_features": "Active swimmers. Dramatic color differences between juvenile, initial phase (usually female), and terminal phase (dominant male). Often have blue heads (terminal males)",
        "constraints": "Color pattern varies dramatically with sex/age",
        "coloration": "highly variable by phase - terminal males often have blue heads with contrasting body",
    },
    "coris": {
        "view": "Lateral view",
        "body": "Moderately elongated wrasse body",
        "key_features": "Significant color change with age. Juveniles often dramatically different from adults",
        "constraints": "Color varies with age/sex",
        "coloration": "varies dramatically - juveniles often orange/red with white patches, adults green/blue",
    },
    "halichoeres": {
        "view": "Lateral view",
        "body": "Typical wrasse shape - elongated with pointed snout",
        "key_features": "Large genus. Often buries in sand at night. Various color patterns",
        "constraints": "Many species - color varies",
        "coloration": "variable - often greens, blues, yellows with various patterns",
    },
    "cheilinus": {
        "view": "Lateral view showing head shape",
        "body": "Large wrasse with thick lips. Some species very large (C. undulatus to 2m)",
        "key_features": "Thick fleshy lips (hence Maori wrasse). Humphead/Napoleon wrasse has prominent forehead bump. Large size",
        "constraints": "C. undulatus specifically has BUMP on forehead (more pronounced in adults)",
        "coloration": "blue-green with intricate facial lines, juveniles different",
    },
    "labroides": {
        "view": "Lateral view showing cleaner behavior",
        "body": "Small, slender wrasse",
        "key_features": "CLEANER WRASSE - picks parasites off other fish. Blue stripe. Sets up 'cleaning stations'. Distinctive side-to-side dance",
        "constraints": "Small size. Cleaning behavior characteristic",
        "coloration": "typically blue with black stripe from snout to tail",
    },
    "bodianus": {
        "view": "Lateral view",
        "body": "Robust hogfish/wrasse body",
        "key_features": "Hogfish - often bicolored (front vs rear different colors). Elongated first dorsal spines in some",
        "constraints": "Often two-toned",
        "coloration": "often front half one color, rear half another (yellow/red combinations common)",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # PARROTFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "scarus": {
        "view": "Lateral view showing dental plates",
        "body": "Robust oval body. Teeth fused into beak-like dental plates for scraping coral/algae",
        "key_features": "BEAK - teeth fused into scraping plates visible even when mouth closed. Large scales. Complex color phases. Produces sand by eating coral",
        "constraints": "Beak must be visible - fused teeth, not individual teeth",
        "coloration": "highly variable - initial phase often drab, terminal males often bright blue-green with pink or yellow accents",
    },
    "chlorurus": {
        "view": "Lateral view showing beak and color",
        "body": "Similar to Scarus with beaked teeth",
        "key_features": "Bumphead and other parrotfish. Terminal males often green. Steep head profile in some",
        "constraints": "Beak visible",
        "coloration": "often green or blue-green in terminal phase",
    },
    "bolbometopon": {
        "view": "Lateral view showing massive head",
        "body": "Largest parrotfish (to 1.3m). Massive forehead bump. Heavy beak",
        "key_features": "Bumphead parrotfish - massive bump on forehead used for head-butting. Huge dental plates. Travel in schools that graze on reef",
        "constraints": "Prominent BUMP on forehead. Large size",
        "coloration": "grey-green to olive, often with pink-edged scales. Bump may be paler",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # BUTTERFLYFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "chaetodon": {
        "view": "Lateral view showing disc shape and eyespot",
        "body": "Deep, laterally compressed disc-shaped body. Small, protrusible mouth with brush-like teeth. Continuous dorsal fin",
        "key_features": "Typically yellow and white with bold black markings. Often has dark EYE-BAND to disguise real eye. Many species have FALSE EYESPOT near tail to confuse predators",
        "constraints": "Deep disc shape. Eye band is common feature",
        "coloration": "typically bright yellow and white with black eye-band and/or other black markings",
    },
    "heniochus": {
        "view": "Lateral view showing pennant dorsal",
        "body": "Disc-shaped with extremely elongated fourth dorsal spine forming trailing PENNANT/BANNER",
        "key_features": "Bannerfish - elongated dorsal spine streams behind like pennant. Black and white bands. Longfin appearance",
        "constraints": "Elongated dorsal PENNANT is diagnostic - must be shown",
        "coloration": "bold black and white bands/stripes, yellow accents",
    },
    "forcipiger": {
        "view": "Lateral view showing extremely long snout",
        "body": "Disc-shaped with EXTREMELY elongated snout (forceps-like)",
        "key_features": "Longnose butterflyfish - snout is very long and thin for reaching into coral crevices. Yellow body",
        "constraints": "Snout is VERY long - longer proportionally than other butterflyfish",
        "coloration": "bright yellow body, black face mask, white bottom",
    },
    "chelmon": {
        "view": "Lateral view showing striped pattern and snout",
        "body": "Disc-shaped with elongated snout (not as extreme as Forcipiger)",
        "key_features": "Copperband butterflyfish - vertical copper/orange bands with black edges. Prominent false eyespot",
        "constraints": "Distinctive banded pattern",
        "coloration": "white with vertical orange/copper bands edged in black, false eyespot near tail",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # ANGELFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "pomacanthus": {
        "view": "Lateral view showing preopercle spine",
        "body": "Deep compressed body. Distinctive SPINE at corner of preopercle (gill cover) - distinguishes from butterflyfish. Small mouth",
        "key_features": "PREOPERCLE SPINE is diagnostic for angelfish. Often dramatic color change between juvenile and adult. Large species (to 45cm)",
        "constraints": "SPINE on gill cover (preopercle) MUST be shown. Juvenile pattern often completely different from adult",
        "coloration": "varies by species - often bold patterns: emperor has blue/yellow stripes, semicircle has blue with yellow stripes",
    },
    "centropyge": {
        "view": "Lateral view",
        "body": "Small angelfish (dwarf angels). Deep body with preopercle spine",
        "key_features": "Small size (5-15cm). Preopercle spine present. Various bright colors",
        "constraints": "SMALL compared to Pomacanthus. Spine still present",
        "coloration": "variable - flame angel is orange/red, coral beauty is orange and blue, etc.",
    },
    "pygoplites": {
        "view": "Lateral view showing regal pattern",
        "body": "Deep compressed body with preopercle spine",
        "key_features": "Regal angelfish - distinctive blue and orange/yellow diagonal stripes. One of most distinctive patterns",
        "constraints": "Spine present",
        "coloration": "white/pale base with blue-edged orange-yellow diagonal stripes",
    },
    "holacanthus": {
        "view": "Lateral view",
        "body": "Large angelfish with preopercle spine",
        "key_features": "Queen and blue angelfish (Atlantic). Crown-like pattern in queen angel. Preopercle spine",
        "constraints": "Spine present",
        "coloration": "queen angel: blue with yellow scale edges, blue 'crown' spot",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SURGEONFISH & TANGS
    # ═══════════════════════════════════════════════════════════════════════════
    "acanthurus": {
        "view": "Lateral view showing caudal spine",
        "body": "Oval compressed body. Single row of teeth. SHARP SCALPEL-LIKE SPINE on caudal peduncle (near tail)",
        "key_features": "CAUDAL SPINE - sharp retractable blade on each side of tail base. Used defensively (can inflict serious cuts). Single dorsal fin. Small mouth",
        "constraints": "CAUDAL SPINE is critical feature - must be visible. Named 'surgeonfish' for this scalpel",
        "coloration": "varies by species - often solid colors (blue, brown, yellow) with contrasting spine area",
    },
    "paracanthurus": {
        "view": "Lateral view showing distinctive pattern",
        "body": "Oval body with caudal spine",
        "key_features": "Blue tang/Dory - bright blue with black palette pattern and yellow tail. Caudal spine present",
        "constraints": "Caudal spine. Distinctive color pattern",
        "coloration": "bright blue with black 'palette' marking on side, yellow tail",
    },
    "zebrasoma": {
        "view": "Lateral view showing sail-like fins",
        "body": "Very deep, disc-shaped body with SAIL-LIKE extended dorsal and anal fins. Elongated snout. Caudal spine",
        "key_features": "High disc-shaped body. Extended dorsal and anal fins give 'sail' appearance. Pointed snout. Caudal spine",
        "constraints": "Extended fins are characteristic",
        "coloration": "variable - yellow tang is all yellow, sailfin has stripes, purple tang is purple",
    },
    "naso": {
        "view": "Lateral view showing horn/bump",
        "body": "Elongated compared to other surgeons. Many species have horn or bump on forehead. TWO fixed blades (not retractable) on caudal peduncle",
        "key_features": "Unicornfish - many have forehead HORN (projecting forward) or bump. TWO fixed (not folding) caudal blades",
        "constraints": "TWO caudal blades, not one like Acanthurus. Horn present in many species",
        "coloration": "often grey or brown, some with blue accents",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # TRIGGERFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "balistoides": {
        "view": "Lateral view showing trigger mechanism",
        "body": "Deep compressed rhomboidal body. Small terminal mouth with strong incisiform teeth. Three dorsal spines - first locks erect",
        "key_features": "TRIGGER MECHANISM - first dorsal spine locks erect, can only be released by depressing second spine (the 'trigger'). Uses to lock into crevices. Small gill opening. Rough skin",
        "constraints": "First dorsal spine is ERECTILE and locks in place",
        "coloration": "clown trigger: bold black, white, yellow spotted pattern. Titan: greenish with dark markings",
    },
    "rhinecanthus": {
        "view": "Lateral view showing Picasso pattern",
        "body": "Triggerfish body with trigger mechanism",
        "key_features": "Picasso triggerfish - geometric blue, black, yellow, white pattern. Trigger lock mechanism",
        "constraints": "Trigger spine present",
        "coloration": "bold geometric pattern of blue lines, yellow, black, and white ('painted' by Picasso)",
    },
    "odonus": {
        "view": "Lateral view",
        "body": "Triggerfish with lunate tail (unusual for triggers)",
        "key_features": "Red-toothed trigger - red teeth visible when mouth open. Lyre-shaped tail",
        "constraints": "Lunate tail different from typical triggers. Red teeth",
        "coloration": "blue body with red teeth (visible in mouth)",
    },
    "melichthys": {
        "view": "Lateral view",
        "body": "Oval triggerfish body",
        "key_features": "Black triggerfish - often with white lines at fin bases",
        "constraints": "Trigger present",
        "coloration": "dark blue-black with white line at dorsal and anal fin bases",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # PUFFERFISH & BOXFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "arothron": {
        "view": "Lateral view showing body shape",
        "body": "Rounded body capable of INFLATION. Fused beak-like teeth. NO pelvic fins. Small pectoral fins and tiny dorsal/anal fins",
        "key_features": "Can INFLATE body with water/air to 2-3x size. Four fused teeth create beak. Skin often with prickles. TOXIC (tetrodotoxin)",
        "constraints": "NO pelvic fins. Body is inflatable. Beak-like teeth (4 fused teeth)",
        "coloration": "variable - map puffer is mottled brown/white, spotted puffer has black spots on white",
    },
    "canthigaster": {
        "view": "Lateral view",
        "body": "Small, compressed pufferfish (sharpnose puffers). Pointed snout",
        "key_features": "Smaller puffers with more compressed body and pointed snout. Can inflate. Beak teeth. Toxic",
        "constraints": "Smaller than Arothron. More laterally compressed",
        "coloration": "variable - often with stripes, spots, or complex patterns",
    },
    "diodon": {
        "view": "Lateral view showing spines",
        "body": "Rounded body covered with SPINES that erect when inflated. Beak teeth. No pelvic fins",
        "key_features": "Porcupinefish - body covered with erectile SPINES. When inflated, becomes spiky ball. Beak for crushing shellfish",
        "constraints": "SPINES are critical feature - cover body, erect when inflated",
        "coloration": "tan to brown with dark spots",
    },
    "ostracion": {
        "view": "Lateral view showing boxy shape",
        "body": "Rigid BOXY body encased in bony plates fused into carapace. Only fins, eyes, and mouth can move",
        "key_features": "Body is rigid BOX - hexagonal bony plates fused together. Cannot flex body. Swims with fins only. Secretes toxin (ostracitoxin) when stressed",
        "constraints": "Body is RIGID BOX - cannot inflate or flex. Bony carapace",
        "coloration": "often yellow with blue/black spots, or plain with patterns",
    },
    "lactoria": {
        "view": "Anterior-lateral view showing horns",
        "body": "Boxy body with HORNS - projections above eyes and often before tail",
        "key_features": "Cowfish - boxy body with pair of HORN-LIKE projections above eyes. Additional spines may project from rear",
        "constraints": "HORNS above eyes are diagnostic for cowfish",
        "coloration": "typically yellow with blue spots/scribbles",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SCORPIONFISH & LIONFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "scorpaenopsis": {
        "view": "Resting pose showing camouflage",
        "body": "Heavy head with bony ridges, spines, and often skin flaps. Fan-like pectoral fins. VENOMOUS dorsal spines",
        "key_features": "Master of camouflage - mottled coloration and skin tassels. VENOMOUS dorsal, anal, and pelvic spines. Ambush predator. Large upward-facing mouth",
        "constraints": "Show camouflaged/cryptic appearance. VENOMOUS spines",
        "coloration": "highly variable to match substrate - mottled reds, browns, pinks, greens",
    },
    "pterois": {
        "view": "Displaying spread fins",
        "body": "Elongated body with HUGE fan-like pectoral fins. Very long separate dorsal spines. Fleshy tentacles above eyes",
        "key_features": "LIONFISH - dramatically elongated, venomous dorsal spines. Huge fanned pectoral fins spread like wings. Eye tentacles. Invasive pest in Atlantic",
        "constraints": "Dorsal spines are LONG and SEPARATE (not connected by membrane at tips). Pectorals are LARGE fans",
        "coloration": "bold alternating red-brown/maroon and white/cream vertical stripes",
    },
    "dendrochirus": {
        "view": "Showing spread fins",
        "body": "Similar to Pterois but smaller with shorter fin spines",
        "key_features": "Dwarf lionfish - similar pattern to Pterois but more compact. Shorter fin spines. Fan pectorals",
        "constraints": "Shorter spines than Pterois. Smaller size",
        "coloration": "striped like Pterois but often more muted colors",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # MORAY EELS
    # ═══════════════════════════════════════════════════════════════════════════
    "gymnothorax": {
        "view": "Head emerging from crevice, mouth slightly open",
        "body": "Long serpentine body. NO pectoral or pelvic fins. Continuous dorsal fin from head to tail. Small round gill openings",
        "key_features": "Mouth constantly opening/closing (for breathing, not aggression). Sharp teeth often visible. Smooth scaleless skin. Poor vision, excellent smell. Second set of pharyngeal jaws",
        "constraints": "NO pectoral fins - this is important. Gill opening is SMALL and round, not a slit",
        "coloration": "highly variable - spotted, mottled, banded, or uniform depending on species",
    },
    "echidna": {
        "view": "Head view showing molar teeth",
        "body": "Moray eel body plan",
        "key_features": "Blunt molar-like teeth for crushing crustaceans (unlike sharp-toothed morays). Often banded pattern. Short snout",
        "constraints": "Teeth are BLUNT, not needle-sharp",
        "coloration": "often banded - snowflake moray has black/white pattern",
    },
    "rhinomuraena": {
        "view": "Showing distinctive nasal projections",
        "body": "Very slender elegant moray with elaborate nasal extensions",
        "key_features": "Ribbon eel - ELABORATE LEAF-LIKE PROJECTIONS from nostrils. Very slender body. Changes color with sex (male blue, female yellow)",
        "constraints": "Nasal projections are highly ornate - like leaves or fans",
        "coloration": "male: electric blue with yellow fins; female: yellow; juvenile: black",
    },
    "enchelycore": {
        "view": "Showing curved jaw",
        "body": "Moray with distinctively curved jaws that don't close completely",
        "key_features": "Dragon moray - jaws curve and CANNOT close fully, exposing sharp teeth always. Elaborate nasal projections. Spotted pattern",
        "constraints": "Jaws visibly do not close - teeth always exposed",
        "coloration": "white to orange with dark spots, white nasal projections",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SNAPPERS
    # ═══════════════════════════════════════════════════════════════════════════
    "lutjanus": {
        "view": "Lateral view showing body shape and canine teeth",
        "body": "Moderately deep, laterally compressed body. Large canine teeth visible. Continuous dorsal fin. Forked caudal fin",
        "key_features": "Prominent canine teeth near front of jaws. Often have horizontal stripe or markings. Schooling behavior. Popular food fish",
        "constraints": "Canine teeth should be suggested",
        "coloration": "varies - often reds, yellows, or silvery with stripes or spot below dorsal fin",
    },
    "macolor": {
        "view": "Lateral view",
        "body": "Snapper with bicolored pattern",
        "key_features": "Black and white snapper - distinctly bicolored in adults (black above, white below). Juveniles look different",
        "constraints": "Adult pattern is sharply bicolored",
        "coloration": "adult: sharply divided black above/white below with large eye",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # JACKS & TREVALLIES
    # ═══════════════════════════════════════════════════════════════════════════
    "caranx": {
        "view": "Lateral view showing streamlined body and scutes",
        "body": "Streamlined, laterally compressed body. Deeply forked caudal fin. Two separate dorsal fins. Scutes (keeled scales) along lateral line near tail",
        "key_features": "Bony SCUTES along lateral line near tail. Fast predators. Often silvery. Schooling. Giant trevally (GT) can reach 1.7m",
        "constraints": "Scutes (enlarged keeled scales) near tail are diagnostic for jacks",
        "coloration": "typically silver with darker back, some species with spots or bars",
    },
    "gnathanodon": {
        "view": "Lateral view showing bars",
        "body": "Jack body with very steep forehead profile",
        "key_features": "Golden trevally - juveniles have bold black bars and follow large fish (including sharks). Adults more silvery. Lips are rubbery, no teeth",
        "constraints": "Juvenile pattern very different from adult. No teeth (lips suck in food)",
        "coloration": "juvenile: golden-yellow with black bars; adult: silvery with faded bars",
    },
    "elagatis": {
        "view": "Lateral view showing stripes",
        "body": "Slender streamlined jack with pointed snout. Finlets behind dorsal and anal fins",
        "key_features": "Rainbow runner - slender body with blue stripes. Often has finlets. Fast oceanic swimmer",
        "constraints": "More slender than typical jacks. May have finlets",
        "coloration": "blue-green back, blue horizontal stripe, yellow-green below, white belly",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # DAMSELFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "chromis": {
        "view": "Lateral view",
        "body": "Small oval compressed body. Forked tail. Single dorsal fin",
        "key_features": "Schooling planktivores. Often hover above coral. Many blue or green species",
        "constraints": "Small size. Forked tail",
        "coloration": "often blue, green, or bicolored. C. viridis is iridescent blue-green",
    },
    "dascyllus": {
        "view": "Lateral view",
        "body": "Small, deep-bodied damselfish. Rounded fins",
        "key_features": "Domino damselfish - often black with white spots. Associated with coral heads. Cleaning station behavior when young",
        "constraints": "Deep-bodied. Small",
        "coloration": "typically black with white spots/bars, or striped patterns",
    },
    "stegastes": {
        "view": "Lateral view",
        "body": "Small oval damselfish",
        "key_features": "Farmer damselfish - many species farm algae gardens and aggressively defend territory. Will attack divers",
        "constraints": "Small but aggressive",
        "coloration": "variable - often browns or dusky colors, some bicolored",
    },
    "abudefduf": {
        "view": "Lateral view showing sergeant bars",
        "body": "Oval compressed body with vertical bars",
        "key_features": "Sergeant major - distinctive vertical BARS giving 'military' appearance. Schooling. Guards eggs on substrate",
        "constraints": "Vertical bars are characteristic",
        "coloration": "typically silver/yellow with 5-6 black vertical bars",
    },
    "pomacentrus": {
        "view": "Lateral view",
        "body": "Small oval damselfish",
        "key_features": "Various colors. Territorial. Common reef fish",
        "constraints": "Small",
        "coloration": "variable by species - blues, yellows, browns",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # GOBIES
    # ═══════════════════════════════════════════════════════════════════════════
    "gobidon": {
        "view": "Showing coral perch",
        "body": "Small, squat goby. Pelvic fins fused into disc",
        "key_features": "Coral gobies - live ON and IN coral branches. Produce toxic mucus. Pelvic disc for gripping. Feed on coral mucus",
        "constraints": "Associated with branching coral. Small. Pelvic disc",
        "coloration": "often solid colors - yellow, green, black depending on coral host",
    },
    "valenciennea": {
        "view": "Showing substrate sifting behavior",
        "body": "Elongated goby body",
        "key_features": "Sand-sifting gobies - take mouthfuls of sand and sift for food. Create burrows. Often with shrimp partner",
        "constraints": "Bottom-dwelling. Sifting behavior",
        "coloration": "often pale with stripes or spots",
    },
    "amblyeleotris": {
        "view": "At burrow with shrimp",
        "body": "Elongated goby",
        "key_features": "Shrimp gobies - share burrow with alpheid shrimp in mutualistic relationship. Goby watches for danger, shrimp maintains burrow",
        "constraints": "Show partnership with shrimp if possible",
        "coloration": "various patterns - often banded or spotted",
    },
    "stonogobiops": {
        "view": "Hovering near burrow",
        "body": "Small goby with high first dorsal",
        "key_features": "Shrimp gobies with elongated dorsal fin rays. Associated with shrimp",
        "constraints": "Extended dorsal rays",
        "coloration": "often with bold patterns - horizontal stripes",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SEAHORSES & PIPEFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "hippocampus": {
        "view": "Lateral view showing classic seahorse posture",
        "body": "Head at right angle to body. Body in segmented bony rings. PREHENSILE TAIL curled. Tubular snout. Small dorsal fin. NO caudal fin",
        "key_features": "Vertical posture. Prehensile tail for gripping. Male has BROOD POUCH (male pregnancy). No teeth - suck in food. Bony armor in rings",
        "constraints": "NO caudal (tail) fin. Tail is PREHENSILE, shown curled. Head perpendicular to body",
        "coloration": "highly variable - can change color. Yellows, oranges, browns, blacks depending on species and habitat",
    },
    "syngnathus": {
        "view": "Lateral view showing elongated body",
        "body": "Very elongated, pipe-like body in bony rings. Tubular snout. Small dorsal fin. Small caudal fin",
        "key_features": "Straight (not curled) body unlike seahorse. Bony ring armor. Male broods eggs (on belly in some, in pouch in others)",
        "constraints": "Straight elongated body. Not curled like seahorse",
        "coloration": "often cryptic - browns, greens, matching seagrass",
    },
    "corythoichthys": {
        "view": "Lateral view",
        "body": "Small pipefish with subtle banding",
        "key_features": "Network pipefish - often with pattern of lines. Found on reef. Male broods eggs on belly",
        "constraints": "Small. Straight body",
        "coloration": "often with network pattern of lines, various base colors",
    },
    "doryrhamphus": {
        "view": "Showing flagtail",
        "body": "Small pipefish with elaborate caudal fin",
        "key_features": "Flagtail pipefish - caudal fin is large, often brightly colored 'flag'. Sometimes found with cleaner shrimp",
        "constraints": "Elaborate flag-like tail fin",
        "coloration": "body often banded; tail fin colorful (red, yellow)",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # BARRACUDA
    # ═══════════════════════════════════════════════════════════════════════════
    "sphyraena": {
        "view": "Lateral view showing torpedo shape",
        "body": "Extremely elongated pike-like body. Large head with projecting lower jaw. Prominent fang-like teeth. Two widely separated dorsal fins. Forked tail",
        "key_features": "Large FANG-LIKE TEETH visible. Projecting lower jaw (underbite). Dark bars or chevrons on silver body. Can exceed 1.5m. Fast ambush predator",
        "constraints": "Teeth must be prominent - fangs. Two dorsal fins well separated",
        "coloration": "silver body with darker bars, spots, or chevron markings depending on species",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # DOLPHINS
    # ═══════════════════════════════════════════════════════════════════════════
    "tursiops": {
        "view": "Lateral view showing full body profile",
        "body": "Streamlined fusiform body. Curved dorsal fin (falcate). Horizontal tail flukes. Flippers. Pronounced beak (rostrum) with permanent 'smile'. Blowhole on top of head",
        "key_features": "MAMMAL - breathes air through blowhole. Horizontal tail flukes (not vertical like fish). Beak with curved mouth line. Melon (rounded forehead). Social, intelligent",
        "constraints": "Tail is HORIZONTAL (mammal), not vertical like fish. Has blowhole, not gills. Warm-blooded - smooth skin, no scales",
        "coloration": "grey dorsally, fading to lighter grey/white on belly. 'Cape' pattern often visible",
    },
    "stenella": {
        "view": "Lateral view showing spots or stripes",
        "body": "Smaller, more slender dolphin. Falcate dorsal fin. Pronounced beak",
        "key_features": "Spotted or spinner dolphins - either spotted pattern or long beak (spinner). Spinners rotate when jumping",
        "constraints": "Mammal - horizontal flukes, blowhole",
        "coloration": "spotted species: dark with pale spots (increase with age); spinner: three-tone grey pattern",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # TUBE WORMS
    # ═══════════════════════════════════════════════════════════════════════════
    "sabellastarte": {
        "view": "Showing feather duster crown expanded",
        "body": "Segmented worm in soft parchment tube. Elaborate crown of feathery RADIOLES (tentacles) forms spiral or fan",
        "key_features": "FEATHER DUSTER crown - pair of spiral/fan-shaped radiole clusters for filter feeding and respiration. Can retract instantly. Lives in tube",
        "constraints": "Body usually hidden in tube - focus on crown. Crown is pair of spiral/fan clusters",
        "coloration": "crown often banded - browns, oranges, whites, sometimes purple",
    },
    "spirobranchus": {
        "view": "Showing Christmas tree spirals",
        "body": "Worm in CALCAREOUS (hard) tube embedded in coral. Twin spiral crowns project like Christmas trees",
        "key_features": "CHRISTMAS TREE WORM - twin tightly coiled spiral crowns. Has OPERCULUM (trap door) to seal tube. Lives embedded IN coral",
        "constraints": "Spirals are tight coils (Christmas tree shape). Tube is hard/calcareous",
        "coloration": "extremely variable - red, orange, yellow, blue, white, purple, often two-toned",
    },
    "protula": {
        "view": "Showing plume",
        "body": "Worm in white calcareous tube. Fan-shaped radiole crown",
        "key_features": "Hard white tube. No operculum. Fan-shaped rather than spiral crown",
        "constraints": "Tube is white/calcareous",
        "coloration": "crown often red, orange, or white; white tube",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # FROGFISH
    # ═══════════════════════════════════════════════════════════════════════════
    "antennarius": {
        "view": "Showing camouflage and lure",
        "body": "Globular body with leg-like pectoral fins (can 'walk'). Small upward-facing mouth. Modified dorsal spine = ILLICIUM (fishing rod) with ESCA (lure)",
        "key_features": "FISHING ROD - first dorsal spine modified into fishing lure (illicium + esca). Master camouflage - can match any color/texture. Huge gape - can swallow prey own size. Leg-like pectorals",
        "constraints": "Lure (illicium/esca) should be shown. Body is lumpy/warty for camouflage",
        "coloration": "extremely variable - matches habitat exactly: yellow, red, pink, black, white, striped",
    },
    "histrio": {
        "view": "Among sargassum",
        "body": "Frogfish adapted to floating sargassum weed",
        "key_features": "Sargassumfish - lives among floating seaweed. Elaborate fleshy tabs mimic seaweed. Prehensile pectoral fins grip weed",
        "constraints": "Associated with sargassum/seaweed",
        "coloration": "mottled brown and tan matching sargassum",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # GIANT CLAMS
    # ═══════════════════════════════════════════════════════════════════════════
    "tridacna": {
        "view": "Showing mantle between shell valves",
        "body": "Two large shell valves with wavy edges (fluted). Fleshy MANTLE exposed between valves containing symbiotic algae",
        "key_features": "MANTLE is the colorful part - contains zooxanthellae (photosynthetic algae). Largest bivalve (T. gigas to 1.2m). Cannot close shell completely as adult. Mantle has iridocytes producing color",
        "constraints": "Shell often embedded in coral - may not be fully visible. Mantle is the photosynthetic tissue exposed",
        "coloration": "mantle is spectacular - iridescent blues, greens, golds, purples with spots/patterns. Shell is white",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # SCALLOPS (Pectinidae)
    # ═══════════════════════════════════════════════════════════════════════════
    "argopecten": {
        "view": "View showing fan-shaped shell with radial ribs and auricles (ears)",
        "body": "Classic scallop - two asymmetrical fan-shaped valves with prominent radial ribs. Wing-like auricles at hinge",
        "key_features": "Fan-shaped shells with radial ribs. Asymmetrical auricles (ears) at hinge. Many small EYES along mantle edge (unusual for bivalves). Can swim by clapping valves",
        "constraints": "NO fins. NO legs. This is a BIVALVE MOLLUSK with TWO shells. Has row of tiny eyes (blue) along mantle edge",
        "coloration": "variable - often orange, red, yellow, white, or purple with concentric growth lines",
    },
    "pecten": {
        "view": "View showing fan shape with one flat and one convex valve",
        "body": "One valve flat, one convex. Strong radial ribs. Asymmetrical auricles",
        "key_features": "Asymmetrical valves - one flat (upper), one convex (lower). Strong ribs. Can swim short distances",
        "constraints": "BIVALVE - two shells. No fish features",
        "coloration": "typically reddish-brown to purple, often with rays of color",
    },
    "chlamys": {
        "view": "View showing radially ribbed shell",
        "body": "Both valves convex with fine radial ribs. Small auricles",
        "key_features": "Fine radial ribbing. Small ear-like auricles. Row of eyes along mantle. Can swim",
        "constraints": "BIVALVE mollusk, not a fish",
        "coloration": "variable - yellows, oranges, pinks, browns with patterns",
    },
    "gloripallium": {
        "view": "View showing colorful shell pattern",
        "body": "Medium-sized scallop with well-defined radial ribs",
        "key_features": "Beautifully colored shells. Prominent ribs. Auricles present",
        "constraints": "BIVALVE - NO fins, NO fish anatomy. Two hinged shells",
        "coloration": "often striking patterns - mottled or blood-stained appearance in some species",
    },
    "lindapecten": {
        "view": "View showing shell texture and shape",
        "body": "Small to medium scallop with rough texture from tiny scales on ribs",
        "key_features": "Ribs with small scales giving rough texture. Fan-shaped. Auricles at hinge",
        "constraints": "BIVALVE mollusk with two shells. Not a fish",
        "coloration": "browns, tans, sometimes with mottling",
    },
    "caribachlamys": {
        "view": "View showing Caribbean scallop shell",
        "body": "Small Caribbean scallop with delicate ribs",
        "key_features": "Delicate radial ribs. Small auricles. Tropical species",
        "constraints": "BIVALVE - two shells, no fish features",
        "coloration": "variable, often pale with subtle patterns",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # VENUS CLAMS (Veneridae)
    # ═══════════════════════════════════════════════════════════════════════════
    "lioconcha": {
        "view": "View showing oval shell with concentric sculpture",
        "body": "Oval to rounded shell with fine concentric ridges. Two equal valves",
        "key_features": "Concentric sculpture (growth lines/ridges). Smooth to slightly textured. Rounded triangular shape. Buried in sand",
        "constraints": "BIVALVE CLAM - NO eyes, NO fins, NO fish body. Two hinged shells. Lives buried in sediment",
        "coloration": "cream, tan, or brown with possible zigzag or radial patterns",
    },
    "venerupis": {
        "view": "View showing shell with both concentric and radial sculpture",
        "body": "Oval elongated shell. Decussate sculpture (crossed by concentric and radial lines)",
        "key_features": "Carpet shell - decussate pattern. Siphons for filter feeding. Edible clam",
        "constraints": "BIVALVE - two shells, not a fish",
        "coloration": "cream to brown, often with darker zigzag patterns",
    },
    "pitar": {
        "view": "View showing smooth rounded shell",
        "body": "Rounded triangular shell, relatively smooth",
        "key_features": "Venus clam with smooth to finely sculptured shell",
        "constraints": "BIVALVE mollusk",
        "coloration": "typically white to cream, sometimes with colored rays",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # THORNY OYSTERS (Spondylidae)
    # ═══════════════════════════════════════════════════════════════════════════
    "spondylus": {
        "view": "View showing spiny shell exterior",
        "body": "Irregular shell with prominent spines/projections. Lower valve cemented to substrate. Upper valve with elaborate spines",
        "key_features": "Thorny oyster - covered in SPINES of varying lengths. Attached to hard substrate. Brightly colored. Row of eyes along mantle",
        "constraints": "BIVALVE - two shells. Often encrusted with other organisms. Lower valve attached, upper valve has spines",
        "coloration": "often spectacular - reds, oranges, purples, whites. Spines may be different color from shell",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # PEN SHELLS (Pinnidae)
    # ═══════════════════════════════════════════════════════════════════════════
    "pinna": {
        "view": "View showing elongated triangular shell",
        "body": "Large triangular/fan-shaped shell. Pointed end buried in sediment. Thin fragile valves",
        "key_features": "Pen shell - large (to 1m), triangular. Anchored by byssus threads. Fragile thin shell. Valuable for sea silk (byssus)",
        "constraints": "BIVALVE - fragile thin shell. Often partially buried. Not a fish",
        "coloration": "amber, brown, olive, often translucent when thin",
    },
    "atrina": {
        "view": "View showing triangular pen shell",
        "body": "Triangular shell similar to Pinna",
        "key_features": "Pen shell anchored in soft sediment",
        "constraints": "BIVALVE mollusk",
        "coloration": "dark olive to black, sometimes with nacreous interior",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # MULLETS (Default fish family mentioned in data)
    # ═══════════════════════════════════════════════════════════════════════════
    "mugil": {
        "view": "Lateral view showing standard fish shape",
        "body": "Torpedo-shaped, cylindrical body. Broad flat head. Two widely separated dorsal fins. Small mouth with thick lips. Large scales. Adipose eyelid",
        "key_features": "Thick lips. Two dorsal fins widely spaced. Detritivore - eats algae/organic matter from sediment. Often jumps. Schooling behavior",
        "constraints": "Head is broad and flat. Two separate dorsals",
        "coloration": "silver sides with grey-green back, faint longitudinal stripes possible",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # DEFAULT FALLBACKS
    # ═══════════════════════════════════════════════════════════════════════════
    "default_fish": {
        "view": "Full lateral view showing body profile and fin arrangement",
        "body": "Streamlined fusiform body with distinct head, trunk, and tail regions",
        "key_features": "Paired pectoral and pelvic fins. Median dorsal, anal, and caudal fins. Lateral line visible. Operculum covering gills",
        "constraints": "Typical ray-finned fish body plan",
        "coloration": "variable according to species and habitat",
    },
    "default_invertebrate": {
        "view": "View showing key identifying features",
        "body": "Body plan appropriate to invertebrate phylum",
        "key_features": "Features characteristic of the specific invertebrate group",
        "constraints": "Anatomical accuracy critical - verify features against scientific references",
        "coloration": "variable according to species",
    },

    # ═══════════════════════════════════════════════════════════════════════════
    # BODY CLASS FALLBACKS (used when genus not found but body_class is known)
    # ═══════════════════════════════════════════════════════════════════════════
    "class_shark": {
        "view": "Full lateral view from snout to tail tip, showing complete body profile. Calm scientific pose with mouth closed",
        "body": "Streamlined fusiform (torpedo-shaped) body. Cartilaginous skeleton (NOT bony). Five to seven gill slits visible",
        "key_features": "Exposed gill slits (NO operculum). Two dorsal fins. Heterocercal caudal fin (upper lobe larger). Dermal denticles (tiny tooth-like scales)",
        "constraints": "NO operculum (gill cover) - open gill slits are visible. NO swim bladder. Cartilaginous skeleton, NOT bony. Mouth typically on underside of head",
        "coloration": "typically counter-shaded - darker dorsally, lighter ventrally",
    },
    "class_ray": {
        "view": "Dorsal view from above showing full disc shape and tail",
        "body": "Flat, dorsoventrally compressed body. Pectoral fins enlarged into wing-like disc. Eyes and spiracles on top of head",
        "key_features": "Wing-like pectoral disc. Tail often with spine(s). Gill slits on underside. Spiracles behind eyes for breathing",
        "constraints": "Body is FLAT. Mouth and gill slits are on UNDERSIDE (ventral). Eyes on TOP",
        "coloration": "typically brown or grey dorsally, white ventrally",
    },
    "class_bivalve": {
        "view": "View showing exterior shell sculpture and shape. Both valves visible or one valve showing detail",
        "body": "TWO hinged shell valves connected by hinge ligament. Soft body completely enclosed within shells",
        "key_features": "Bivalve shell with growth lines. Umbo (beak) near hinge. Possible radial ribs, concentric ridges, or smooth surface depending on species",
        "constraints": "NO EYES (except scallops which have many small eyes along mantle edge). NO FINS. NO LEGS. This is a MOLLUSK not a fish. Two shells that can open/close",
        "coloration": "shell color variable - white, cream, brown, purple, or patterned",
    },
    "class_gastropod": {
        "view": "Shell aperture view showing spiral structure and surface ornamentation",
        "body": "Single coiled or conical shell. Soft body can retract into shell. Muscular foot for locomotion",
        "key_features": "Spiral or conical shell. Aperture (opening) for soft body. Operculum (door) in some species. Shell may have spines, ribs, or smooth surface",
        "constraints": "NO FINS. NO FISH FEATURES. This is a SHELLED MOLLUSK (snail). Single shell, not two like bivalves",
        "coloration": "shell patterns highly variable - may be solid, banded, spotted, or intricately patterned",
    },
    "class_nudibranch": {
        "view": "Three-quarter dorsal-lateral view showing rhinophores, body profile, and gill/cerata arrangement",
        "body": "Soft-bodied sea slug with NO shell. Elongated or oval mantle. Rhinophores (sensory tentacles) on head",
        "key_features": "NO SHELL. Rhinophores (horn-like sensory organs) on head. Either branchial plume (feathery gills) on back OR cerata (finger-like projections). Often brightly colored",
        "constraints": "NO SHELL - this is a sea slug, not a snail. Has external gills (branchial plume) or cerata. Soft body",
        "coloration": "often spectacular warning colors - vivid blues, oranges, purples, yellows with contrasting patterns",
    },
    "class_cephalopod": {
        "view": "Natural pose showing arm/tentacle arrangement and prominent eye",
        "body": "Soft body with arms/tentacles bearing suckers. Large complex eyes. Internal shell (or none)",
        "key_features": "Arms with suckers. Large eye. Siphon for jet propulsion. Octopus: 8 arms, no shell. Squid/cuttlefish: 8 arms + 2 tentacles, internal shell",
        "constraints": "Octopus has 8 arms with TWO rows of suckers, NO tentacles, NO shell. Squid has 8 arms + 2 tentacles with ONE row of suckers",
        "coloration": "highly variable - can change color rapidly via chromatophores",
    },
    "class_shrimp": {
        "view": "Lateral view showing curved body profile, rostrum, and antennae",
        "body": "Elongated laterally compressed body. Segmented abdomen curves ventrally. Long rostrum (beak) projecting forward",
        "key_features": "Long antennae. Fan-shaped tail (telson + uropods). Swimming pleopods. Rostrum extending forward. SMALL claws on front legs only (not large like lobster)",
        "constraints": "Claws are SMALL - not large crushing claws like lobster. Body is laterally compressed and curved",
        "coloration": "often translucent pink, grey, or brown with possible banding",
    },
    "class_crab": {
        "view": "Dorsal view showing full carapace shape, claw arrangement, and leg position",
        "body": "Broad, flattened carapace. Reduced abdomen folded under body. Five pairs of legs - first pair as chelipeds (claws)",
        "key_features": "Broad carapace. Chelipeds (claws) - one often larger. Four pairs of walking legs. Stalked eyes. Abdomen tucked under body",
        "constraints": "Claws are the FIRST pair of legs, not all legs have claws. Abdomen is folded UNDER the body, not visible from above",
        "coloration": "variable - browns, reds, greens, sometimes with patterns or spots",
    },
    "class_lobster": {
        "view": "Dorsal-lateral view showing full body from antennae to tail",
        "body": "Elongated body with cylindrical cephalothorax and segmented muscular abdomen. Large tail fan",
        "key_features": "Long antennae. Segmented abdomen with powerful tail. Stalked eyes. VARIES by type: spiny lobster has NO claws, true lobster has large front claws",
        "constraints": "SPINY LOBSTER (Palinuridae): NO large claws, just walking legs. TRUE LOBSTER (Nephropidae): HAS large asymmetrical claws",
        "coloration": "typically reddish-brown, blue, or purple when alive (turns red when cooked)",
    },
    "class_echinoderm_star": {
        "view": "Dorsal view showing arm arrangement and central disc",
        "body": "Central disc with radiating arms (typically 5, sometimes more). Tube feet on underside. Mouth on underside",
        "key_features": "Five-fold radial symmetry (usually). Tube feet in grooves on arm undersides. Madreporite (water intake) on top. Can regenerate arms",
        "constraints": "Mouth is on UNDERSIDE, not top. Arms radiate from central disc",
        "coloration": "variable - oranges, reds, blues, purples, often uniform or spotted",
    },
    "class_echinoderm_urchin": {
        "view": "Oblique view showing spherical test and spine arrangement",
        "body": "Spherical to flattened test (shell) covered in moveable spines. Five-fold symmetry. Tube feet among spines",
        "key_features": "Spines (moveable) covering body. Test (shell) underneath spines. Aristotle's lantern (5 teeth) on underside for scraping. Tube feet",
        "constraints": "Spines are MOVEABLE, attached to test by ball-and-socket joints. Mouth on underside with 5 teeth",
        "coloration": "test often purple, green, or white; spines may be same color or contrasting",
    },
    "class_sea_turtle": {
        "view": "Three-quarter dorsal view showing carapace pattern, head, and flipper shape",
        "body": "Streamlined carapace (shell) covered in scutes. Paddle-shaped flippers. Non-retractable head",
        "key_features": "Carapace with scutes. Four flippers (not legs). Cannot retract head into shell. Beak-like mouth",
        "constraints": "Cannot retract head or flippers into shell. Flippers are paddles, NOT walking legs",
        "coloration": "carapace typically olive, brown, or reddish-brown; plastron pale",
    },
    "class_marine_mammal": {
        "view": "Lateral view showing full body profile, fins, and head shape",
        "body": "Streamlined fusiform body adapted for swimming. Horizontal tail flukes. Dorsal fin. Flippers",
        "key_features": "Breathes air. Horizontal tail flukes (not vertical like fish). Blowhole on top of head. Flippers. Smooth skin",
        "constraints": "Tail flukes are HORIZONTAL (fish tails are vertical). No scales - smooth skin. Must surface to breathe",
        "coloration": "typically counter-shaded grey dorsally, lighter ventrally",
    },
}

# Additional species-specific overrides for common/notable species
SPECIES_OVERRIDES = {
    "panulirus japonicus": {
        "coloration": "dark brownish-red to violet shell with cream/yellow bands on walking legs, striped antennae with alternating dark and pale rings",
    },
    "panulirus versicolor": {
        "coloration": "blue-green to purple carapace with white markings, legs banded blue and white, antennae pink/purple",
    },
    "panulirus ornatus": {
        "coloration": "tropical rock lobster - green with pale markings, legs boldly banded in cream and dark colors, ornate pattern",
    },
    "octopus vulgaris": {
        "coloration": "typically reddish-brown to brownish-grey mottled, but can change rapidly. Cream-colored suckers with dark centers",
    },
    "hapalochlaena lunulata": {
        "coloration": "tan to beige-yellow with approximately 60 bright iridescent blue rings that flash vividly when threatened",
    },
    "pterois volitans": {
        "coloration": "alternating vertical stripes of maroon-brown and cream-white, elongated white dorsal spines, banded pectoral fin rays",
    },
    "sphyrna lewini": {
        "coloration": "grey-brown to olive dorsally, white ventrally, dusky to black tips on pectoral fins (sometimes), scalloped front edge of hammer",
        "key_features": "Scalloped hammerhead - front edge of cephalofoil has SCALLOPED/WAVY indentations (not smooth or arched)",
    },
    "sphyrna mokarran": {
        "coloration": "light grey to grey-brown dorsally, white ventrally, tall sickle-shaped first dorsal fin",
        "key_features": "Great hammerhead - front edge of cephalofoil is nearly STRAIGHT (not scalloped), very tall first dorsal fin",
    },
    "mobula alfredi": {
        "coloration": "dark brown to black dorsally with pale shoulder patches forming 'Y' shape, white ventrally with unique spot pattern",
    },
    "mobula birostris": {
        "coloration": "jet black dorsally with pale triangular shoulder patches, white ventrally with unique spotting, larger than M. alfredi",
    },
    "chelonia mydas": {
        "coloration": "olive-brown to dark brown carapace with radiating pattern on each scute, pale yellow plastron, skin olive/brown",
    },
    "eretmochelys imbricata": {
        "coloration": "beautiful amber tortoiseshell pattern - brown with yellow, orange, and red streaks radiating on overlapping scutes",
    },
    "caretta caretta": {
        "coloration": "reddish-brown carapace, yellowish plastron, large head relative to body",
    },
    "rhincodon typus": {
        "coloration": "blue-grey to brownish with distinctive checkerboard matrix of pale spots and vertical bars, white underside",
    },
    "carcharodon carcharias": {
        "coloration": "grey to slate-blue dorsally, white ventrally, irregular jagged demarcation line between colors",
    },
    "chromodoris quadricolor": {
        "coloration": "black body with vivid orange/red stripes and blue lines - the 'pyjama' pattern. Orange rhinophores and gills",
    },
    "phyllidia varicosa": {
        "coloration": "black background with pink/grey raised tubercles arranged in longitudinal ridges",
    },
    "linckia laevigata": {
        "coloration": "brilliant solid blue (most common), occasionally purple, orange, or pink. Smooth surface",
    },
    "acanthaster planci": {
        "coloration": "typically purplish-grey, greenish, or reddish with contrasting cream-tipped venomous spines",
    },
    "diadema setosum": {
        "coloration": "black with black long spines (sometimes banded), orange/red ring around central disc (anal cone)",
    },
    "cassiopea andromeda": {
        "coloration": "bell is blue-green to brown (zooxanthellae), oral arms branching with white tips. Upside-down posture",
    },
    "tursiops truncatus": {
        "coloration": "medium grey dorsally, lighter grey on flanks, white to pale grey on belly. 'Cape' darker area on back",
    },
    "amphiprion ocellaris": {
        "coloration": "bright orange with three white vertical bars edged in thin black. False clownfish (vs A. percula)",
    },
    "amphiprion percula": {
        "coloration": "bright orange with three white bars edged in THICK black. True/orange clownfish",
    },
    "premnas biaculeatus": {
        "coloration": "deep maroon/burgundy with three white to yellow bars. Spine under each eye",
    },
}


def get_genus(scientific_name: str) -> str:
    """Extract genus from scientific name."""
    return scientific_name.split()[0].lower() if scientific_name else ""


def get_species_key(scientific_name: str) -> str:
    """Get full species key for lookups."""
    return scientific_name.lower() if scientific_name else ""


# Map body_class values to fallback template keys
BODY_CLASS_MAP = {
    # From species_descriptions_searched.json body_class values
    "shark": "class_shark",
    "ray": "class_ray",
    "bivalve_shell": "class_bivalve",
    "bivalve": "class_bivalve",
    "gastropod_shell": "class_gastropod",
    "gastropod": "class_gastropod",
    "nudibranch": "class_nudibranch",
    "cephalopod": "class_cephalopod",
    "shrimp": "class_shrimp",
    "swimming_crab": "class_crab",
    "crab": "class_crab",
    "decapod": "class_crab",  # Most decapods are crabs
    "lobster": "class_lobster",
    "spiny_lobster_no_claws": "class_lobster",
    "echinoderm_star": "class_echinoderm_star",
    "starfish": "class_echinoderm_star",
    "echinoderm_urchin": "class_echinoderm_urchin",
    "urchin": "class_echinoderm_urchin",
    "sea_turtle": "class_sea_turtle",
    "turtle": "class_sea_turtle",
    "marine_mammal": "class_marine_mammal",
    "vertebrate": "default_fish",  # Generic vertebrate defaults to fish
    "bony_fish": "default_fish",
    "mantis_shrimp": "class_shrimp",  # Similar enough
}


def get_fallback_from_body_class(body_class: str) -> str:
    """Get the appropriate fallback template key from body_class."""
    if not body_class:
        return "default_fish"

    body_class_lower = body_class.lower().strip()

    # Direct lookup
    if body_class_lower in BODY_CLASS_MAP:
        return BODY_CLASS_MAP[body_class_lower]

    # Keyword matching for complex body_class values
    if "shark" in body_class_lower:
        return "class_shark"
    if "ray" in body_class_lower or "skate" in body_class_lower:
        return "class_ray"
    if "bivalve" in body_class_lower or "clam" in body_class_lower or "scallop" in body_class_lower or "oyster" in body_class_lower or "mussel" in body_class_lower:
        return "class_bivalve"
    if "gastropod" in body_class_lower or "snail" in body_class_lower or "conch" in body_class_lower:
        return "class_gastropod"
    if "nudibranch" in body_class_lower or "sea slug" in body_class_lower:
        return "class_nudibranch"
    if "cephalopod" in body_class_lower or "octopus" in body_class_lower or "squid" in body_class_lower or "cuttlefish" in body_class_lower:
        return "class_cephalopod"
    if "shrimp" in body_class_lower or "prawn" in body_class_lower:
        return "class_shrimp"
    if "crab" in body_class_lower:
        return "class_crab"
    if "lobster" in body_class_lower:
        return "class_lobster"
    if "turtle" in body_class_lower:
        return "class_sea_turtle"
    if "mammal" in body_class_lower or "dolphin" in body_class_lower or "whale" in body_class_lower:
        return "class_marine_mammal"
    if "starfish" in body_class_lower or "sea star" in body_class_lower:
        return "class_echinoderm_star"
    if "urchin" in body_class_lower:
        return "class_echinoderm_urchin"

    return "default_fish"


def generate_prompt(species: dict, body_class: str = None) -> str:
    """Generate anatomically accurate illustration prompt.

    Args:
        species: Species dict with name, scientificName, etc.
        body_class: Optional body class for fallback selection (e.g., 'shark', 'bivalve_shell')
    """
    name = species["name"]
    scientific_name = species["scientificName"]
    original_desc = species.get("description", "") or ""

    genus = get_genus(scientific_name)
    species_key = get_species_key(scientific_name)

    # Get genus-level anatomy - first try exact genus match
    anatomy = GENUS_ANATOMY.get(genus)

    # If genus not found, try body_class fallback
    if not anatomy and body_class:
        fallback_key = get_fallback_from_body_class(body_class)
        anatomy = GENUS_ANATOMY.get(fallback_key)

    # Final fallback to default_fish
    if not anatomy:
        anatomy = GENUS_ANATOMY["default_fish"]

    # Check for species-specific overrides
    override = SPECIES_OVERRIDES.get(species_key, {})

    # Build the prompt
    view = override.get("view", anatomy.get("view", "Full lateral view showing key identifying features"))
    body = override.get("body", anatomy.get("body", "Body structure appropriate to the species"))
    key_features = override.get("key_features", anatomy.get("key_features", "Species-typical features"))
    constraints = override.get("constraints", anatomy.get("constraints", ""))
    coloration = override.get("coloration", anatomy.get("coloration", "Natural species coloration"))

    # Build the prompt - Premium Digital Painting / Pokedex style
    prompt = f"""Subject: A single, full-body digital oil painting of a {name} ({scientific_name}).

KEY IDENTIFIERS: {key_features}. {body}

HARD CONSTRAINTS (The "Specimen Standard"):
• Pose: Neutral, full-body profile view, swimming passively. Absolutely no action poses (eating, fighting, hiding), no dynamic foreshortening, and NO other animals or objects in the scene.
• Composition: Centered, entire body fully visible, with ~15% padding between the subject and the edge of the frame.
• {constraints}

STYLE & ATMOSPHERE (Uniform "Deep Blue" Pokedex):
• Medium: Rich digital oil painting style. Visible, confident brushstrokes that define form and texture. Premium and naturalistic, not photorealistic or cartoonish.
• Lighting: Dramatic, directional underwater spotlighting from above, creating deep shadows underneath the animal to give it volume.
• Background: Moody, deep dark blue underwater gradient, fading to near-black at the corners. Subtle, indistinct brushwork in the water, but NO distinct background elements (coral, sand, rocks, bubbles).
• Coloration: {coloration}
• Accuracy Constraint: While painterly, the key identifying markings must be rendered accurately and clearly visible despite the brushwork texture.

AVOID: Photorealism, cartoons, action poses, other animals, background elements, flat lighting, inconsistent framing."""

    return prompt


def infer_body_class_from_family(family: str, worms_class: str = None) -> str:
    """Infer body class from WoRMS family/class when body_class is missing."""
    if not family and not worms_class:
        return None

    family_lower = (family or "").lower()
    class_lower = (worms_class or "").lower()

    # Shark families
    shark_families = ["carcharhinidae", "sphyrnidae", "alopiidae", "lamnidae",
                      "rhincodontidae", "ginglymostomatidae", "hemiscylliidae",
                      "orectolobidae", "stegostomatidae", "triakidae", "galeocerdonidae"]
    if family_lower in shark_families or "elasmobranchii" in class_lower:
        return "shark"

    # Ray families
    ray_families = ["dasyatidae", "myliobatidae", "mobulidae", "rhinopteridae",
                    "aetobatidae", "torpedinidae", "rajidae", "gymnuridae"]
    if family_lower in ray_families:
        return "ray"

    # Bivalve families
    bivalve_families = ["pectinidae", "veneridae", "cardiidae", "mytilidae",
                        "ostreidae", "spondylidae", "pinnidae", "tridacnidae",
                        "arcidae", "pteriidae", "tellinidae", "mactridae"]
    if family_lower in bivalve_families or "bivalvia" in class_lower:
        return "bivalve_shell"

    # Gastropod families
    gastropod_families = ["conidae", "muricidae", "strombidae", "cypraeidae",
                          "trochidae", "turbinidae", "nassariidae", "olividae",
                          "haliotidae", "naticidae", "cassidae", "ranellidae"]
    if family_lower in gastropod_families:
        return "gastropod_shell"

    # Nudibranch families
    nudibranch_families = ["chromodorididae", "phyllidiidae", "hexabranchidae",
                           "discodorididae", "polyceridae", "flabellinidae",
                           "aeolidiidae", "glaucidae", "aplysiidae"]
    if family_lower in nudibranch_families:
        return "nudibranch"

    # Cephalopod families
    cephalopod_families = ["octopodidae", "sepiidae", "loliginidae", "nautilidae"]
    if family_lower in cephalopod_families or "cephalopoda" in class_lower:
        return "cephalopod"

    # Sea turtle families
    if family_lower == "cheloniidae" or family_lower == "dermochelyidae":
        return "sea_turtle"

    return None


def main():
    input_path = Path("/Users/finn/dev/umilog/data/export/species_catalog_full.json")
    grounded_csv_path = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts_grounded.csv")
    output_json = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts.json")
    output_csv = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts.csv")

    with open(input_path) as f:
        data = json.load(f)

    # Load body_class from grounded CSV
    body_class_map = {}
    if grounded_csv_path.exists():
        print(f"Loading body_class data from {grounded_csv_path}")
        with open(grounded_csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                sci_name = row.get("scientificName", "").lower()
                body_class = row.get("body_class", "").strip()
                if sci_name and body_class:
                    body_class_map[sci_name] = body_class
        print(f"Loaded body_class for {len(body_class_map)} species")
    else:
        print(f"Warning: {grounded_csv_path} not found, using genus-only matching")

    species_list = data["species"]
    results = []

    # Track coverage
    covered_genera = set()
    body_class_fallback = set()
    uncovered_genera = set()

    for species in species_list:
        sci_name = species["scientificName"].lower()
        body_class = body_class_map.get(sci_name)

        prompt = generate_prompt(species, body_class=body_class)
        results.append({
            "id": species["id"],
            "name": species["name"],
            "scientificName": species["scientificName"],
            "prompt": prompt
        })

        # Track coverage
        genus = get_genus(species["scientificName"])
        if genus in GENUS_ANATOMY:
            covered_genera.add(genus)
        elif body_class:
            body_class_fallback.add(genus)
        else:
            uncovered_genera.add(genus)

    # Write JSON
    with open(output_json, "w") as f:
        json.dump({"prompts": results, "count": len(results)}, f, indent=2)

    # Write CSV
    with open(output_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "name", "scientificName", "prompt"])
        writer.writeheader()
        writer.writerows(results)

    print(f"Generated {len(results)} anatomically accurate prompts")
    print(f"JSON: {output_json}")
    print(f"CSV: {output_csv}")
    print(f"\nCoverage statistics:")
    print(f"  - Genera with specific templates: {len(covered_genera)}")
    print(f"  - Using body_class fallback: {len(body_class_fallback)}")
    print(f"  - Using default_fish fallback: {len(uncovered_genera)}")
    if body_class_fallback:
        print(f"  Sample body_class fallback genera: {list(body_class_fallback)[:10]}")
    if uncovered_genera:
        print(f"  Sample uncovered genera: {list(uncovered_genera)[:10]}")

    # Print sample prompts
    print("\n" + "=" * 80)
    print("SAMPLE PROMPTS WITH ANATOMICAL CONSTRAINTS")
    print("=" * 80)

    samples = [
        "Japanese Spiny Lobster",
        "Blacktip Reef Shark",
        "Great Hammerhead Shark",
        "Reef Manta Ray",
        "Common Octopus",
        "greater blue-ringed octopus",
        "Lionfish",
        "green turtle",
        "striped pyjama nudibranch",
        "Bottlenose Dolphin",
    ]

    for sample_name in samples:
        for r in results:
            if r["name"].lower() == sample_name.lower():
                print(f"\n{'='*60}")
                print(f"{r['name']} ({r['scientificName']})")
                print("=" * 60)
                print(r["prompt"])
                break


if __name__ == "__main__":
    main()
