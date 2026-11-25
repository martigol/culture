//
//  StorylineMyths.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import Foundation

/// Storylines for the myths retold from Berens, and the interactive
/// questions that pause each storyline at its turning point.
extension Storyline {
    static let mythScripts: [Story.ID: [(String, String, SceneBackdrop)]] = [
        "birth-of-zeus": [
            ("The hungry king",
             "Cronus had been warned: one of his children would take his throne. So each time a child was born, he swallowed it whole.",
             .dusk),
            ("A mother's choice",
             "Five children gone. When the sixth was born, Rhea made up her mind — this one, she would save.",
             .divine),
            ("The cave on Mount Ida",
             "In a cave in Crete, a goat gave the baby milk and eagles brought him nectar, while warriors clashed their shields to drown his cries.",
             .summit),
            ("Father and son",
             "Grown strong, Zeus made Cronus give back every child he had swallowed. Then came war — Olympus against the Titans.",
             .battle),
            ("Thunder",
             "The Cyclops forged him thunderbolts. The sea rose mountains high, the earth shook — and when the mist cleared, Zeus ruled the sky.",
             .sea),
        ],
        "apollo-daphne": [
            ("The god of light",
             "Apollo had just slain the monstrous Python. Proud of his silver bow, he laughed at little Eros and his tiny arrows.",
             .sun),
            ("Two arrows",
             "From the peak of Parnassus, Eros took aim twice: a golden arrow for Apollo, a leaden one for the nymph Daphne.",
             .wings),
            ("The chase",
             "Apollo burned with love. Daphne fled from him like a hunted deer, until her strength gave out and she called to the gods for help.",
             .dusk),
            ("Evergreen",
             "Bark closed around her, branches grew from her arms. Apollo wove her leaves into a crown, and swore they would stay green for ever.",
             .divine),
        ],
        "niobe": [
            ("A proud queen",
             "Niobe, queen of Thebes, had seven sons and seven daughters — and she never let anyone forget it.",
             .dusk),
            ("An insult to a goddess",
             "\"Leto has only two children,\" she told the people. \"Honour me instead.\" Leto's two children were Apollo and Artemis.",
             .divine),
            ("Silver arrows",
             "Unseen arrows flew. Apollo struck the sons, Artemis the daughters, until one child was left in Niobe's arms.",
             .battle),
            ("The weeping rock",
             "Alone among her dead, Niobe turned to stone. High on Mount Sipylus, the rock is said to weep to this day.",
             .summit),
        ],
        "birth-of-aphrodite": [
            ("Rose-coloured foam",
             "Where the blood of Uranus fell into the sea, the waves turned pink and began to foam — and something rose from them.",
             .sea),
            ("Pearls",
             "Aphrodite, goddess of love, stood in a sea-shell and shook out her hair. Every drop that fell became a pearl.",
             .divine),
            ("Cyprus blooms",
             "The breeze carried her to Cyprus. Where her foot touched the sand, meadows sprang up and the whole island burst into flower.",
             .wings),
            ("Olympus",
             "Crowned in gold, she was led to Olympus. Every god wanted to marry her; it was Hephaestus, the smith, who won her.",
             .sun),
        ],
        "poseidon-deep": [
            ("Brother of Zeus",
             "When the sons of Cronus divided the world, Poseidon took the sea — every wave, every storm, every shore.",
             .sea),
            ("The year without the sea",
             "Once he plotted against Zeus, and was stripped of the ocean for a year. He spent it building the walls of Troy.",
             .battle),
            ("A dolphin's courtship",
             "He wooed the sea-nymph Amphitrite in the shape of a dolphin, and she became queen of the deep.",
             .wings),
            ("Scylla",
             "But Amphitrite was jealous. A few herbs in a well, and the beautiful Scylla became a six-headed monster waiting above the straits.",
             .dusk),
            ("Earth-shaker",
             "When Poseidon strikes the ground with his trident, the earth trembles and springs burst from the rock.",
             .sea),
        ],
        "hill-of-ares": [
            ("The god of war",
             "Ares loved battle for its own sake. He swept through armies like a whirlwind, and Strife ran before his chariot.",
             .battle),
            ("Roaring like ten thousand bulls",
             "At Troy, Athena helped a mortal wound him. Ares fled the field bellowing — and Zeus told him he was the most hateful of all the gods.",
             .dusk),
            ("A son of the sea",
             "When Ares killed Poseidon's son for insulting his daughter, the sea-god demanded justice.",
             .sea),
            ("The first trial",
             "The gods met on a rocky hill in Athens to judge the god of war. The hill still bears his name: the Areopagus.",
             .summit),
        ],
        "phaethon": [
            ("Son of the Sun",
             "Phaethon swore the sun-god Helios was his father. His friends laughed. So he went to the palace of the sun to prove it.",
             .sun),
            ("A sacred promise",
             "Helios swore by the river Styx to grant him any wish. Phaethon asked to drive the chariot of the sun for one day.",
             .divine),
            ("The horses bolt",
             "The fiery horses felt a stranger's hand and ran wild — up until the heavens shook, down until the earth caught fire.",
             .battle),
            ("Thunderbolt",
             "Forests burned and rivers boiled away. The earth cried out to Zeus, and Zeus raised his hand.",
             .summit),
            ("Amber",
             "Phaethon fell into the river Eridanus. His sisters wept until they became poplars, and their tears hardened into amber.",
             .dusk),
        ],
        "persephone": [
            ("The hundred-flowered narcissus",
             "Picking flowers in a meadow, Persephone saw a narcissus with a hundred blossoms, and bent to pick it.",
             .wings),
            ("The earth opens",
             "The ground split at her feet. Hades rose in a chariot drawn by black horses and carried her down into the dark.",
             .battle),
            ("Torches from Etna",
             "Her mother Demeter lit two torches in the fires of Mount Etna and searched the world for nine days and nights.",
             .dusk),
            ("The first winter",
             "In her grief, Demeter let nothing grow. Fields died, people starved, and even Zeus had to give way.",
             .summit),
            ("Six seeds",
             "Persephone could come home — if she had eaten nothing below. But she had tasted a pomegranate.",
             .divine),
            ("Spring",
             "So each year she returns to Hades and the earth lies bare. And each year she comes back, and spring comes with her.",
             .sun),
        ],
    ]

    /// Turning-point questions: scene index → question (asked after that scene).
    static let questions: [Story.ID: [Int: SceneQuestion]] = [
        // New myths
        "birth-of-zeus": [1: SceneQuestion(
            prompt: "How did Rhea fool the all-swallowing Cronus?",
            options: ["She hid the baby in the sea", "She gave him a stone wrapped like a baby", "She put him to sleep for a hundred years"],
            answer: 1,
            reveal: "A stone in swaddling clothes — and he swallowed it without a second look.")],
        "apollo-daphne": [2: SceneQuestion(
            prompt: "Daphne begs the gods to save her. What do they do?",
            options: ["Turn her into a laurel tree", "Give her wings to fly away", "Hide her in her father's river"],
            answer: 0,
            reveal: "A laurel — which is why victors, poets and Apollo himself wear laurel crowns.")],
        "niobe": [2: SceneQuestion(
            prompt: "What did the gods do with the grieving queen?",
            options: ["Turned her to stone", "Made her a star", "Sent her to the underworld"],
            answer: 0,
            reveal: "Stone — but a stone that never stops weeping.")],
        "birth-of-aphrodite": [1: SceneQuestion(
            prompt: "Where did Aphrodite first step ashore?",
            options: ["Crete", "Cyprus", "Sicily"],
            answer: 1,
            reveal: "Cyprus — her rock still stands in the sea near Paphos.")],
        "poseidon-deep": [1: SceneQuestion(
            prompt: "In what form did Poseidon win Amphitrite?",
            options: ["A white bull", "A dolphin", "A great wave"],
            answer: 1,
            reveal: "A dolphin — sailors long after saw dolphins as Poseidon's messengers.")],
        "hill-of-ares": [2: SceneQuestion(
            prompt: "The gods put Ares on trial. What was the verdict?",
            options: ["Guilty — banished to Tartarus", "Not guilty", "Guilty — stripped of his sword"],
            answer: 1,
            reveal: "Acquitted. The hill where the gods sat became Athens' highest court.")],
        "phaethon": [1: SceneQuestion(
            prompt: "Would you take the reins of the sun?",
            options: ["Of course — I'm the son of the Sun", "No — some gifts are traps", "Only with my father beside me"],
            answer: 1,
            reveal: "Helios begged him to choose anything else. Phaethon wouldn't listen.")],
        "persephone": [3: SceneQuestion(
            prompt: "What could keep Persephone in the underworld for ever?",
            options: ["Eating its food", "Looking back as she left", "Crossing the river Styx"],
            answer: 0,
            reveal: "A single bite of the food of the dead. Had she eaten?")],

        // Site stories
        "sounion": [1: SceneQuestion(
            prompt: "Victorious, Theseus sails home. What does he forget?",
            options: ["To change the sails to white", "To thank the gods", "His father's sword"],
            answer: 0,
            reveal: "The white sails. And on the cliff, his father was watching.")],
        "knossos": [1: SceneQuestion(
            prompt: "What did Ariadne give Theseus to escape the labyrinth?",
            options: ["A map", "A ball of thread", "A lamp"],
            answer: 1,
            reveal: "A ball of thread, unwound behind him all the way to the heart of the maze.")],
        "delphi": [1: SceneQuestion(
            prompt: "Croesus asked if he should attack Persia. What happened?",
            options: ["He conquered Persia", "He destroyed his own empire", "He never went to war"],
            answer: 1,
            reveal: "\"A great empire will fall,\" said the oracle. It was his.")],
        "medusa": [1: SceneQuestion(
            prompt: "How could Perseus fight Medusa without turning to stone?",
            options: ["Close his eyes", "Look only at her reflection", "Fight her at night"],
            answer: 1,
            reveal: "He watched her in his polished shield.")],
        "parthenon": [1: SceneQuestion(
            prompt: "What do you think stood inside the temple?",
            options: ["A giant statue of Athena", "The throne of Zeus", "The tomb of Pericles"],
            answer: 0,
            reveal: "Athena Parthenos — twelve metres of gold and ivory.")],
        "olympia": [0: SceneQuestion(
            prompt: "What did the first Olympic champion win?",
            options: ["A bag of gold", "A wreath of olive", "A bronze statue"],
            answer: 1,
            reveal: "A crown of wild olive — and glory.")],
    ]
}
