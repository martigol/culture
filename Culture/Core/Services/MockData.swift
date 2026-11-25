import Foundation

/// Sample content so every screen renders meaningfully during development.
/// Image credits: docs/IMAGE_CREDITS.md. Delete once the real backend lands.
enum MockData {
    /// The sites, then the myths retold from Berens (BerensMyths.swift).
    static let stories: [Story] = siteStories + berensMyths

    private static let siteStories: [Story] = [
        Story(
            id: "parthenon", title: "The Parthenon", subtitle: "Temple of the Maiden",
            category: .places, region: "Athens", location: GeoPoint(37.9715, 23.7267), era: "447–432 BC", durationMinutes: 6,
            summary: "Crowning the Acropolis for twenty-five centuries, the Parthenon was built to honour Athena — and to show the world what Athens could become.",
            body: "Under Pericles, the architects Iktinos and Kallikrates raised a temple without a single truly straight line. Its columns swell gently, its floor rises at the centre, and its corners lean inward — subtle corrections that make the building appear perfectly straight to the human eye.\n\nInside stood Pheidias' towering statue of Athena Parthenos, clad in ivory and gold. Over the centuries the Parthenon became a church, a mosque and finally a powder magazine, until a Venetian shell in 1687 tore through its heart. What survives still defines the idea of classical beauty.",
            audioDurationSeconds: 342,
            artwork: Artwork(imageName: "parthenon", credit: "George E. Koronaios · CC BY-SA 4.0", focus: .init(x: 0.6, y: 0.5)),
            isRecommended: true
        ),
        Story(
            id: "delphi", title: "The Oracle of Delphi", subtitle: "Where Apollo spoke in riddles",
            category: .myths, region: "Phocis", location: GeoPoint(38.4824, 22.5010), era: "8th c. BC – AD 390", durationMinutes: 7,
            summary: "Kings and generals climbed the slopes of Parnassus to hear Apollo's will, spoken through the Pythia in words that could be read two ways.",
            body: "Zeus, it was said, released two eagles from opposite ends of the earth. Where they met, he set the omphalos — the navel of the world. That place was Delphi.\n\nFor a thousand years the Pythia sat above a cleft in the rock and answered questions of war, colonies and love. When Croesus of Lydia asked whether to attack Persia, she replied that he would destroy a great empire. He did — his own.",
            audioDurationSeconds: 418,
            artwork: Artwork(imageName: "delphi", credit: "HerrAdams · CC BY-SA 4.0", focus: .init(x: 0.62, y: 0.5)),
            isRecommended: true
        ),
        Story(
            id: "sounion", title: "Poseidon's Watch", subtitle: "The temple at Cape Sounion",
            category: .gods, region: "Attica", location: GeoPoint(37.6501, 24.0246), era: "444–440 BC", durationMinutes: 5,
            summary: "On a cliff above the Aegean, King Aegeus waited for a white sail. The sea that took him still bears his name.",
            body: "Theseus sailed to Crete to face the Minotaur, promising his father that if he lived, his ship would return under white sails. Victorious but careless, he forgot. From the headland of Sounion, Aegeus saw black sails on the horizon and threw himself into the sea — the Aegean.\n\nCenturies later Athenians raised a marble temple to Poseidon here, the last sight of home for sailors leaving Attica and the first on their return.",
            audioDurationSeconds: 296,
            artwork: Artwork(imageName: "sounion", credit: "A.Savin · CC BY-SA 3.0", focus: .init(x: 0.5, y: 0.3)),
            isRecommended: true
        ),
        Story(
            id: "knossos", title: "The Labyrinth of Knossos", subtitle: "Minotaur, Theseus & Ariadne",
            category: .myths, region: "Crete", location: GeoPoint(35.2980, 25.1632), era: "c. 1900–1350 BC", durationMinutes: 8,
            summary: "Beneath the palace of King Minos lay a maze no one escaped — until a princess handed a hero a ball of thread.",
            body: "Knossos was the beating heart of Minoan Crete, a palace of more than a thousand interlocking rooms. Its bewildering corridors and the bull imagery painted on its walls may have inspired the legend of the Labyrinth.\n\nAriadne, daughter of Minos, gave Theseus a thread to unwind as he walked into the dark. He slew the Minotaur and followed the thread back into the light.",
            audioDurationSeconds: 470,
            artwork: Artwork(imageName: "knossos", credit: "Jebulon · CC0")
        ),
        Story(
            id: "zeus", title: "The Artemision Bronze", subtitle: "Zeus — or Poseidon?",
            category: .gods, region: "Cape Artemision", location: GeoPoint(38.9710, 23.2280), era: "c. 460 BC", durationMinutes: 5,
            summary: "Pulled from a shipwreck in 1926, a bronze god poised to hurl a weapon that has never been found.",
            body: "Fishermen and divers recovered the statue from the seabed off Cape Artemision. The god stands with arms outstretched, perfectly balanced, about to throw. If he held a thunderbolt, he is Zeus; if a trident, Poseidon. The missing weapon keeps the argument alive.\n\nIt is one of the very few large Greek bronzes to survive — most were melted down for their metal long ago.",
            audioDurationSeconds: 300,
            artwork: Artwork(imageName: "zeus", credit: "Jebulon · CC0", focus: .init(x: 0.5, y: 0.3))
        ),
        Story(
            id: "agamemnon", title: "The Mask of Agamemnon", subtitle: "Gold from a royal tomb",
            category: .artifacts, region: "Mycenae", location: GeoPoint(37.7308, 22.7561), era: "c. 1550 BC", durationMinutes: 4,
            summary: "Heinrich Schliemann believed he had found the face of Homer's king. The mask is older than the Trojan War itself.",
            body: "In 1876 Schliemann uncovered a royal shaft grave at Mycenae and lifted a hammered gold death mask from its burial. Legend says he declared he had gazed upon the face of Agamemnon.\n\nModern dating places the mask centuries before any Trojan War — but the name has stuck, and the serene golden face remains the icon of the Mycenaean age.",
            audioDurationSeconds: 246,
            artwork: Artwork(imageName: "agamemnon", credit: "Jebulon · CC0"),
            isRecommended: true
        ),
        Story(
            id: "mycenae", title: "The Lion Gate", subtitle: "Citadel of Agamemnon",
            category: .history, region: "Argolis", location: GeoPoint(37.7307, 22.7565), era: "c. 1250 BC", durationMinutes: 6,
            summary: "Two stone lions have guarded Mycenae for over three thousand years — the oldest monumental sculpture in Europe.",
            body: "Later Greeks, looking at walls built from boulders too large for any mortal, said the Cyclopes had raised them. Through the Lion Gate passed the rulers of the richest kingdom of the Bronze Age.\n\nIn Homer, this is the home of Agamemnon, who led the Greeks to Troy and returned only to be murdered in his own palace.",
            audioDurationSeconds: 360,
            artwork: Artwork(imageName: "mycenae", credit: "Zde · CC BY-SA 4.0", focus: .init(x: 0.6, y: 0.5))
        ),
        Story(
            id: "nike", title: "Winged Victory", subtitle: "The Nike of Samothrace",
            category: .artifacts, region: "Samothrace", location: GeoPoint(40.5003, 25.5302), era: "c. 190 BC", durationMinutes: 5,
            summary: "Headless and armless, she still seems to land on the prow of a warship, wind pressing marble robes against her body.",
            body: "Nike, goddess of victory, was carved to celebrate a naval triumph and set above a fountain in the sanctuary of the Great Gods on Samothrace. Found in fragments in 1863, she now commands the Daru staircase of the Louvre.\n\nHer sculptor mastered something marble should not be able to do: movement.",
            audioDurationSeconds: 288,
            artwork: Artwork(imageName: "nike", credit: "Shonagon · CC0", focus: .init(x: 0.45, y: 0.3))
        ),
        Story(
            id: "epidaurus", title: "Theatre of Epidaurus", subtitle: "Where a whisper reaches the stars",
            category: .places, region: "Argolis", location: GeoPoint(37.5960, 23.0794), era: "4th c. BC", durationMinutes: 5,
            summary: "Fourteen thousand seats, and a coin dropped on stage can be heard in the very last row.",
            body: "Built within the sanctuary of Asclepius, god of healing, the theatre was part of the cure: drama for the soul as well as the body. Its limestone rows filter out low-frequency murmur while carrying the actors' voices.\n\nIt still hosts performances of ancient tragedy every summer.",
            audioDurationSeconds: 302,
            artwork: Artwork(imageName: "epidaurus", credit: "Zde · CC BY-SA 4.0")
        ),
        Story(
            id: "charioteer", title: "The Charioteer of Delphi", subtitle: "A victor frozen in bronze",
            category: .artifacts, region: "Delphi", location: GeoPoint(38.4801, 22.4977), era: "c. 470 BC", durationMinutes: 4,
            summary: "Buried by an earthquake, he survived when nearly every other bronze of his age was melted down.",
            body: "Dedicated to celebrate a chariot victory at the Pythian Games, the Charioteer stands calm at the moment of triumph, reins still in hand. His eyes of glass and stone are among the few originals to survive.\n\nA landslide buried him in 373 BC — and preserved him for us.",
            audioDurationSeconds: 238,
            artwork: Artwork(imageName: "charioteer", credit: "Karmakolle · CC0", focus: .init(x: 0.5, y: 0.25))
        ),
        Story(
            id: "medusa", title: "Medusa", subtitle: "The gorgon's gaze",
            category: .myths, region: "Munich Glyptothek", location: GeoPoint(48.1464, 11.5656), era: "Roman copy of a 5th c. BC original", durationMinutes: 6,
            summary: "Once a priestess, cursed by a goddess and hunted by a hero — her face could turn the living to stone.",
            body: "Perseus approached Medusa using a polished shield as a mirror, never meeting her eyes. From her severed head sprang Pegasus.\n\nThe Rondanini Medusa shows not a monster but a tragic, beautiful face — a shift in how the Greeks imagined her.",
            audioDurationSeconds: 352,
            artwork: Artwork(imageName: "medusa", credit: "Vassil · CC0", focus: .init(x: 0.5, y: 0.65))
        ),
        Story(
            id: "olympia", title: "Ancient Olympia", subtitle: "Where the Games began",
            category: .history, region: "Elis", location: GeoPoint(37.6383, 21.6300), era: "776 BC – AD 393", durationMinutes: 6,
            summary: "Every four years a sacred truce let athletes cross a warring Greece to compete for a crown of olive.",
            body: "At Olympia stood the Temple of Hera, one of the oldest in Greece, and the great Temple of Zeus with its gold-and-ivory statue — a Wonder of the World.\n\nThe Olympic flame for the modern Games is still kindled here, by the sun's rays, before the Temple of Hera.",
            audioDurationSeconds: 340,
            artwork: Artwork(imageName: "olympia", credit: "Joyofmuseums · CC BY-SA 4.0")
        ),
    ]

    static let collections: [StoryCollection] = [
        StoryCollection(id: "olympians", name: "Gods of Olympus", storyIDs: ["zeus", "sounion", "parthenon", "delphi"]),
        StoryCollection(id: "old-gods", name: "Myths of the Old Gods",
                        storyIDs: ["birth-of-zeus", "birth-of-aphrodite", "poseidon-deep", "apollo-daphne",
                                   "niobe", "hill-of-ares", "phaethon", "persephone"]),
        StoryCollection(id: "mycenaean", name: "The Mycenaean Age", storyIDs: ["mycenae", "agamemnon"]),
        StoryCollection(id: "myths", name: "Monsters & Heroes", storyIDs: ["knossos", "medusa"]),
        StoryCollection(id: "listening", name: "Evening Listening", storyIDs: ["epidaurus", "nike", "charioteer"]),
    ]

    static let defaultSaved = ["parthenon", "delphi", "nike"]
    static let defaultOffline = ["knossos"]

    static let scanHistory: [ScanRecord] = [
        ScanRecord(id: UUID(), storyID: "agamemnon", date: .now.addingTimeInterval(-3_600)),
        ScanRecord(id: UUID(), storyID: "charioteer", date: .now.addingTimeInterval(-86_400)),
        ScanRecord(id: UUID(), storyID: "zeus", date: .now.addingTimeInterval(-86_400 * 3)),
    ]

    static func story(_ id: Story.ID) -> Story? { stories.first { $0.id == id } }
}
