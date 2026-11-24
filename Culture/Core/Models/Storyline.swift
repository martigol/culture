//
//  Storyline.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import Foundation

/// Animated backdrops for storyline scenes (GIFs in Resources/Storyline).
enum SceneBackdrop: String, CaseIterable, Sendable {
    /// A figure in a halo of light: gods, revelations, treasure.
    case divine = "storyline-divine"
    /// A silhouette against warm dusk: watchers, builders, the passing of time.
    case dusk = "storyline-dusk"
    /// A winged figure in drifting cloud: flight, victory, messengers.
    case wings = "storyline-wings"

    var url: URL? { Bundle.main.url(forResource: rawValue, withExtension: "gif") }
}

/// One beat of a story told as a sequence of animated scenes.
struct StoryScene: Identifiable, Hashable, Sendable {
    let id: Int
    /// Short scene title, e.g. "The labyrinth".
    let title: String
    /// One to three vivid sentences, read on screen (and aloud if sound is on).
    let text: String
    let backdrop: SceneBackdrop
}

/// The storyline for each story: the tale retold in a handful of cinematic
/// scenes. Hand-written for the sample stories; any other story falls back to
/// its own paragraphs.
enum Storyline {
    static func scenes(for story: Story) -> [StoryScene] {
        let beats = scripts[story.id] ?? fallback(for: story)
        return beats.enumerated().map { index, beat in
            StoryScene(id: index, title: beat.0, text: beat.1, backdrop: beat.2)
        }
    }

    /// Roman numeral for a scene number, "I"…"X".
    static func numeral(_ index: Int) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return index < numerals.count ? numerals[index] : "\(index + 1)"
    }

    private typealias Beat = (String, String, SceneBackdrop)

    /// Up to five paragraphs of the story itself, cycling backdrops.
    private static func fallback(for story: Story) -> [Beat] {
        let paragraphs = ([story.summary] + story.body.components(separatedBy: "\n\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)
        let backdrops = SceneBackdrop.allCases
        return paragraphs.enumerated().map { index, text in
            (index == 0 ? story.title : story.subtitle, text, backdrops[index % backdrops.count])
        }
    }

    private static let scripts: [Story.ID: [Beat]] = [
        "parthenon": [
            ("Athena's gift",
             "Two gods wanted Athens. Poseidon struck the rock and salt water gushed out. Athena planted an olive tree — and the city chose her.",
             .divine),
            ("The builders",
             "Under Pericles, thousands of hands hauled marble up the Acropolis. Iktinos and Kallikrates drew a temple without a single truly straight line.",
             .dusk),
            ("The goddess within",
             "In the shadowed hall stood Athena Parthenos: twelve metres of gold and ivory, her shield catching the lamplight.",
             .divine),
            ("Twenty-five centuries",
             "Temple, church, mosque, powder store, ruin. Stand at its steps at sunset and the marble still glows, as if it remembers.",
             .dusk),
        ],
        "delphi": [
            ("Two eagles",
             "Zeus released two eagles from opposite ends of the world. Where they met, on the slopes of Parnassus, lay the navel of the earth.",
             .wings),
            ("Apollo's voice",
             "Above a cleft in the rock, the Pythia sat on her tripod, breathed the sweet vapours — and Apollo spoke through her lips.",
             .divine),
            ("A riddle for a king",
             "Croesus asked if he should march on Persia. “Cross the river and a great empire will fall.” One did. His own.",
             .dusk),
            ("Silence",
             "By the end of the fourth century AD the oracle had fallen silent. The wind on the mountain still sounds like someone about to answer.",
             .wings),
        ],
        "sounion": [
            ("White sails",
             "Theseus sailed for Crete to face the Minotaur, and made his father a promise: if I live, I'll come home under white sails.",
             .wings),
            ("The watch",
             "Day after day, King Aegeus stood on the cliff at Sounion, his eyes on the horizon.",
             .dusk),
            ("Black sails",
             "Victorious but careless, Theseus forgot. Black sails rose over the sea — and the old king threw himself into the waves.",
             .divine),
            ("Poseidon's temple",
             "The sea still bears his name: the Aegean. High above it, Poseidon's columns catch the last light of every day.",
             .dusk),
        ],
        "knossos": [
            ("A gift from the sea",
             "Poseidon sent King Minos a snow-white bull to sacrifice. Minos kept it for himself — and the gods made him pay.",
             .divine),
            ("The labyrinth",
             "Daedalus built a maze so tangled that even he could barely find the way out. In its heart, the Minotaur waited.",
             .dusk),
            ("Ariadne's thread",
             "Princess Ariadne gave Theseus a ball of thread. He unwound it into the dark, slew the beast, and followed it back to the light.",
             .divine),
            ("Wings of wax",
             "Imprisoned by the king, Daedalus made wings for himself and his son. Icarus, dizzy with the sky, flew too close to the sun.",
             .wings),
        ],
        "zeus": [
            ("Lost at sea",
             "Around 460 BC, a ship carrying a bronze god sank off Cape Artemision. For more than two thousand years he lay in the dark.",
             .dusk),
            ("The god rises",
             "In 1926, sponge divers brought up an arm. Two years later the rest of him surfaced, still poised to throw.",
             .divine),
            ("Thunderbolt or trident?",
             "His hand once gripped a weapon, now lost. A thunderbolt would make him Zeus; a trident, Poseidon. The argument has never ended.",
             .wings),
            ("Perfect balance",
             "Arms spread over two metres, weight on his front foot: a god caught in the instant before he lets fly.",
             .divine),
        ],
        "agamemnon": [
            ("The digger",
             "In 1876, Heinrich Schliemann dug inside the walls of Mycenae, determined to find Homer's heroes.",
             .dusk),
            ("Gold in the dark",
             "In a shaft grave he uncovered a face of beaten gold — eyes closed, beard curled, calm as sleep.",
             .divine),
            ("A famous telegram",
             "Legend says he wired the king of Greece: “I have gazed upon the face of Agamemnon.” He probably never sent it.",
             .dusk),
            ("Older than Troy",
             "The mask is centuries older than any Trojan War. Whoever he was, he was a king — just not that one.",
             .divine),
        ],
        "mycenae": [
            ("Walls of giants",
             "The blocks are so huge that later Greeks swore only the Cyclopes could have lifted them.",
             .dusk),
            ("The lions",
             "Above the gate, two lions rear on either side of a column — the oldest monumental sculpture in Europe.",
             .divine),
            ("The king returns",
             "Through this gate Agamemnon rode home from Troy in triumph, towards a wife who had never forgiven him.",
             .wings),
            ("Rich in gold",
             "Homer called it Mycenae rich in gold. Now only the wind moves through the citadel, and the headless lions keep watch.",
             .dusk),
        ],
        "nike": [
            ("Victory lands",
             "She alights on the prow of a warship, wings still spread, as if she has just flown in from the sea.",
             .wings),
            ("The wind in marble",
             "Her robe presses against her body and streams out behind her. The sculptor carved the wind itself.",
             .dusk),
            ("Found in pieces",
             "In 1863, a French consul dug her out of the ruins of Samothrace, broken into more than a hundred fragments.",
             .divine),
            ("Head held high",
             "She never got her head or arms back. At the top of the Louvre's great staircase, she doesn't need them.",
             .wings),
        ],
        "epidaurus": [
            ("The healer's sanctuary",
             "Pilgrims came to Asclepius, god of medicine, and slept in his temple, hoping he would visit their dreams with a cure.",
             .divine),
            ("A hillside of stone",
             "Into the slope the Greeks set a theatre for some fourteen thousand people, curved like a cupped hand.",
             .dusk),
            ("A whisper reaches the stars",
             "Drop a coin on the stage and the back row hears it fall. The stone rows hush the murmur of the crowd and carry the actor's voice.",
             .wings),
            ("Still playing",
             "Every summer the plays return: the same words, under the same stars, two and a half thousand years later.",
             .dusk),
        ],
        "charioteer": [
            ("A victory",
             "A chariot thundered to victory at the Pythian Games, and its owner paid for a bronze to say so forever.",
             .divine),
            ("Buried by the earth",
             "In 373 BC an earthquake buried him beneath the sanctuary. That burial saved him from being melted down.",
             .dusk),
            ("Eyes that still see",
             "His eyes are glass and stone, his lashes copper. He looks straight past you, calm after the race.",
             .divine),
            ("Frozen in bronze",
             "The horses are gone, the chariot is gone. Only the young driver remains, the reins still in his hand.",
             .wings),
        ],
        "medusa": [
            ("A cursed beauty",
             "Once a beautiful woman, Medusa was turned into a gorgon: hair of living snakes, and a gaze that turned flesh to stone.",
             .divine),
            ("The hero comes",
             "Perseus came armed by the gods — winged sandals, a curved blade, and a shield polished like a mirror.",
             .dusk),
            ("Never look",
             "He watched her only in the shield's reflection, and struck. From her blood sprang Pegasus, the winged horse.",
             .wings),
            ("A protector",
             "Her severed head became a charm. Carved on shields and temples, her face kept evil away.",
             .divine),
        ],
        "olympia": [
            ("Zeus's sanctuary",
             "In a green valley in Elis stood a temple to Zeus, and inside it his seated statue — one of the Seven Wonders of the World.",
             .divine),
            ("776 BC",
             "That year, the first recorded champion won the footrace: Koroibos, a cook from Elis. His prize was a wreath of olive.",
             .dusk),
            ("The sacred truce",
             "Heralds rode out across Greece proclaiming a truce, so athletes and pilgrims could travel to the Games in safety.",
             .wings),
            ("The flame",
             "The ancient Games ended in the 390s AD. Today the Olympic flame is still lit here, from the sun's rays, before every Games.",
             .divine),
        ],
    ]
}
