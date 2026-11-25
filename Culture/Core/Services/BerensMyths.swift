//
//  BerensMyths.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import Foundation

/// Myths retold from E. M. Berens, "The Myths and Legends of Ancient Greece
/// and Rome" (1880, public domain), lightly modernised. Illustrated with
/// "The Old Gods" plates; each is pinned to the place the myth belongs to.
extension MockData {
    static let berensMyths: [Story] = [
        Story(
            id: "birth-of-zeus", title: "The Birth of Zeus", subtitle: "A stone in swaddling clothes",
            category: .gods, region: "Mount Ida, Crete", location: GeoPoint(35.2066, 24.8256), era: "Before Olympus", durationMinutes: 6,
            summary: "Cronus swallowed each of his children the moment they were born. To save the last, their mother Rhea dared to deceive the lord of time.",
            body: """
                Cronus, god of time, had been warned that one of his children would rise up and take his throne. So, as each child was born, he swallowed it whole — Hestia, Demeter, Hera, Hades and Poseidon vanished one after another, to the grief and fury of their mother Rhea.

                When her sixth child was due, Rhea resolved to save this one at least. On the advice of her parents, Uranus and Gaea, she wrapped a stone in baby-clothes and gave it to Cronus, who swallowed it in eager haste without noticing the deception.

                The real child, Zeus, was carried in secret to Crete and hidden in a cave in the heart of Mount Ida. The sacred goat Amalthea gave him milk, the nymphs fed him honey, and eagles and doves brought him nectar and ambrosia. At the mouth of the cave Rhea's priests, the Curetes, clashed their shields together, so that the noise drowned the baby's cries.

                Grown to manhood, Zeus forced his father to give back the children he had swallowed — and the stone that had stood in for him was set up at Delphi as a sacred relic. Then came war: Zeus and his brothers and sisters on Mount Olympus, Cronus and the Titans on Mount Othrys. Freed from their prison, the Cyclops forged thunderbolts for Zeus, the sea rose mountains high, the earth shook to its foundations — and when the mist cleared, Cronus had fallen and Zeus ruled the heavens.
                """,
            audioDurationSeconds: 360,
            artwork: GodPlate.zeusLaurel.artwork
        ),
        Story(
            id: "apollo-daphne", title: "Apollo and Daphne", subtitle: "How the laurel became sacred",
            category: .myths, region: "Vale of Tempe, Thessaly", location: GeoPoint(39.8935, 22.5853), era: "Age of Myth", durationMinutes: 5,
            summary: "Fresh from slaying the Python, Apollo mocked the little archer Eros. Eros answered with two arrows — and a chase that ended in a tree.",
            body: """
                Apollo, eternally young, crowned with laurel and bearing his silver bow, was the god of light, of music and of prophecy. Yet he was rarely happy in love.

                His first love was Daphne, daughter of the river-god Peneus. She had begged her father to let her live free, devoted to the hunt, and to marry no one.

                One day, soon after his victory over the serpent Python, Apollo saw Eros bending his bow and laughed at him, saying such a weapon better suited the one who had just killed the terrible serpent. Eros replied that his arrow would pierce the mocker's own heart. From the summit of Mount Parnassus he drew two darts: one of gold, which inspires love, and one of lead, which creates aversion. The golden shaft struck Apollo; the leaden one struck Daphne.

                Apollo burned with love; Daphne fled from him like a hunted deer. He called to her to stay, but she ran on until, faint with fatigue, she called upon the gods for help. A heavy torpor seized her limbs, and just as Apollo reached out to embrace her, she became a laurel. Sorrowfully he crowned his head with its leaves, and declared that in memory of his love it would stay evergreen for ever, and be sacred to him.
                """,
            audioDurationSeconds: 300,
            artwork: GodPlate.apolloOrbs.artwork
        ),
        Story(
            id: "niobe", title: "The Tears of Niobe", subtitle: "Apollo and Artemis avenge their mother",
            category: .myths, region: "Mount Sipylus, Lydia", location: GeoPoint(38.6226, 27.4566), era: "Age of Myth", durationMinutes: 5,
            summary: "A queen with fourteen children mocked a goddess who had only two. The two were Apollo and Artemis.",
            body: """
                Niobe, daughter of Tantalus and wife of Amphion, king of Thebes, was the proud mother of seven sons and seven daughters.

                Exulting in her children, she one day ridiculed the worship of Leto, who had but one son and one daughter, and told the Thebans to give her, Niobe, the honours and sacrifices they had always offered to the mother of Apollo and Artemis.

                The words had scarcely left her lips before Apollo called on his sister to help him avenge the insult. Their invisible arrows sped through the air. Apollo slew all the sons; Artemis slew the daughters, until only the youngest and best-loved remained, clasped in her mother's arms. Niobe begged the gods to leave her just one child — but even as she prayed, the arrow found this child too.

                Widowed and childless, Niobe sat among her dead. The gods, pitying her unspeakable grief, turned her into stone and carried her to Mount Sipylus, her native mountain, where the rock is said to weep still.
                """,
            audioDurationSeconds: 300,
            artwork: GodPlate.artemisArcher.artwork
        ),
        Story(
            id: "birth-of-aphrodite", title: "Born of the Foam", subtitle: "The rising of Aphrodite",
            category: .gods, region: "Paphos, Cyprus", location: GeoPoint(34.6639, 32.6278), era: "Before Olympus", durationMinutes: 5,
            summary: "Out of the rose-tinted foam of the sea rose the goddess of love and beauty — and where she stepped ashore, the sand turned to meadow.",
            body: """
                When Uranus was wounded by his son Cronus, his blood mingled with the foam of the sea. At once the bubbling waters took on a rosy tint, and from their depths arose, in all the glory of her loveliness, Aphrodite, goddess of love and beauty.

                She shook her long fair hair, and the drops of water that rolled down into the sea-shell she stood in became pure, glistening pearls. Carried on soft, balmy breezes, she floated to Cythera, and then on to the island of Cyprus.

                Lightly she stepped ashore, and under her foot the dry, hard sand became a green meadow, rich with every colour and every sweet scent. The whole island burst into bloom to welcome her. The Seasons dressed her in garments woven by the gods, set a wreath of purest gold on her brow and a glittering chain about her throat.

                Then the nymphs led her to the dazzling halls of Olympus, where every god longed to marry her. It was Hephaestus, the lame god of fire, who won her hand — though she proved as faithless as she was beautiful.
                """,
            audioDurationSeconds: 300,
            artwork: GodPlate.aphroditeBirth.artwork
        ),
        Story(
            id: "poseidon-deep", title: "Lord of the Deep", subtitle: "Poseidon, the earth-shaker",
            category: .gods, region: "Isthmus of Corinth", location: GeoPoint(37.9158, 22.9930), era: "Age of Myth", durationMinutes: 6,
            summary: "Brother of Zeus and master of every sea, Poseidon wooed his queen as a dolphin — and his jealous court made monsters of rivals.",
            body: """
                When the sons of Cronus divided the world, Poseidon took the sea. He bowed to the will of Zeus, and fought beside him when the Giants attacked Olympus, chasing the giant Polybotes across the sea and crushing him beneath the island of Cos.

                Yet the brothers did not always agree. Once Poseidon joined Hera and Athena in a plot to put Zeus in chains. The plot was discovered, and as punishment Poseidon lost his rule over the sea for a whole year — the year in which, with Apollo, he built the walls of Troy for King Laomedon.

                Poseidon married the sea-nymph Amphitrite, whom he won in the form of a dolphin. But Amphitrite grew jealous of Scylla, a beautiful maiden the sea-god loved, and threw magic herbs into the well where Scylla bathed. Scylla became a monster with six heads on six long necks and a voice like a barking dog, who lived high in a cave in the straits and snatched sailors from every passing ship.

                Poseidon's children were as wild as the sea itself — among them the Cyclops, one-eyed giants who worked the forge of Hephaestus deep inside Mount Etna, and their chief, the man-eating Polyphemus, who was at last outwitted and blinded by Odysseus.
                """,
            audioDurationSeconds: 360,
            artwork: GodPlate.poseidonStorm.artwork
        ),
        Story(
            id: "hill-of-ares", title: "The Hill of Ares", subtitle: "When the god of war stood trial",
            category: .gods, region: "Athens", location: GeoPoint(37.9723, 23.7235), era: "Age of Myth", durationMinutes: 5,
            summary: "Hated by the gods, feared by men, Ares loved battle for its own sake. Then Poseidon dragged him before a court in Athens.",
            body: """
                Ares, son of Zeus and Hera, was the god of war, who gloried in strife for its own sake. He passed through armies like a whirlwind, hurling down the brave and the cowardly alike, smashing chariots and helmets, and revelling in the ruin he left behind. Before his chariot ran his twin sister Eris, Strife, with her torch and her hissing adder.

                At every turn his sister Athena opposed him. At Troy she helped the hero Diomedes wound him, and the war-god fled the field roaring like ten thousand bulls. When he complained to Zeus, his father told him he was the most hateful of all the gods of Olympus.

                Once Ares killed Halirrhothios, a son of Poseidon, for insulting his daughter Alcippe. Poseidon summoned him before a tribunal of the gods, held on a hill in Athens. Ares was acquitted — and the hill took his name: the Areopagus, the Hill of Ares, which became the most famous court of justice in the ancient world.

                Only Aphrodite loved him. Tall, young and fearless, sword or lance in his right hand and his round shield on his left arm, he was attended by Terror and Fear — his sons Deimos and Phobos.
                """,
            audioDurationSeconds: 300,
            artwork: GodPlate.aresBattle.artwork
        ),
        Story(
            id: "phaethon", title: "The Sun's Chariot", subtitle: "Phaethon's ride",
            category: .myths, region: "Rhodes", location: GeoPoint(36.4339, 28.2108), era: "Age of Myth", durationMinutes: 6,
            summary: "To prove the sun was his father, a boy asked to drive its chariot for a single day. The sun swore he could.",
            body: """
                Phaethon, son of Helios the sun-god and the ocean-nymph Clymene, was beautiful and proud. When his friend Epaphus refused to believe that the sun was his father, Phaethon ran to his mother. She pointed to the shining sun and told him to go and ask its god himself.

                At the palace of the sun the dazzling rays almost blinded him. Helios, seated among the Hours, Days, Months, Years and Seasons, took off his crown of rays and told his son to come near. Phaethon asked for proof of his love that all the world would see, and Helios swore by the river Styx to grant whatever he asked. The boy asked to drive the chariot of the sun for one whole day.

                Horrified, Helios begged him to choose anything else, but Phaethon would not be moved. As Dawn opened her rosy doors, the Hours yoked the horses; Helios anointed his son's face against the flames and set the crown of rays on his head.

                The moment the fiery horses felt the boy's unsteady hand they bolted — soaring so high they threatened the heavens, plunging so low they set the earth on fire. Mountains and forests burned, rivers dried up. The scorched earth cried to Zeus, who struck Phaethon with a thunderbolt. He fell into the river Eridanus; his sisters, mourning, became poplars, and their tears turned to amber.
                """,
            audioDurationSeconds: 360,
            artwork: GodPlate.apolloSun.artwork
        ),
        Story(
            id: "persephone", title: "Queen of the Underworld", subtitle: "Persephone and the pomegranate",
            category: .myths, region: "Eleusis, Attica", location: GeoPoint(38.0412, 23.5384), era: "Age of Myth", durationMinutes: 7,
            summary: "A girl stooped to pick a flower, and the earth opened. Her mother's grief would bring the first winter to the world.",
            body: """
                Demeter, goddess of the harvest, loved her daughter Persephone so dearly that she knew no happiness except in her company.

                One day, gathering flowers in a meadow, Persephone saw a wondrous narcissus with a hundred blossoms. As she stooped to pick it, the ground split open at her feet, and Hades, grim ruler of the underworld, rose from the abyss in a chariot drawn by four black horses. Ignoring her tears, he seized her and carried her down to his gloomy kingdom.

                Demeter lit two torches in the flames of Mount Etna and searched for nine days and nights. At last Helios, whose eye sees everything, told her the truth: Zeus himself had allowed Hades to take Persephone as his wife. In fury and grief Demeter left Olympus, disguised herself as an old woman, and wandered the earth. At Eleusis she sat to rest by a well beneath an olive tree, and the king's daughters took her home to nurse their baby brother.

                While Demeter grieved, nothing would grow, and the world began to starve. Zeus had to relent: Persephone could return — unless she had eaten in the underworld. But she had swallowed a few seeds of a pomegranate. And so, every year, she spends part of the year below with Hades, and the earth lies bare in mourning; when she returns to her mother, spring returns with her.
                """,
            audioDurationSeconds: 420,
            artwork: GodPlate.oldGods.artwork
        ),
    ]
}
