//
//  GodPlates.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import Foundation

/// "The Old Gods" renders (marble and gold) in Assets ▸ Gods.
enum GodPlate: String, CaseIterable {
    case apolloSun = "god-apollo-sun"
    case apolloOrbs = "god-apollo-orbs"
    case apolloLight = "god-apollo-light"
    case poseidonStorm = "god-poseidon-storm"
    case poseidonCrown = "god-poseidon-crown"
    case poseidonArcher = "god-poseidon-archer"
    case zeusEagle = "god-zeus-eagle"
    case zeusLaurel = "god-zeus-laurel"
    case zeusWings = "god-zeus-wings"
    case aresBattle = "god-ares-battle"
    case aresPortrait = "god-ares-portrait"
    case aresArmor = "god-ares-armor"
    case artemisArcher = "god-artemis-archer"
    case artemisHunt = "god-artemis-hunt"
    case aphroditeBirth = "god-aphrodite-birth"
    case aphrodite = "god-aphrodite"
    case oldGods = "the-old-gods"

    var artwork: Artwork { Artwork(imageName: rawValue, credit: "The Old Gods") }
}

extension Story {
    /// Extra plates of the gods in this story, shown after its main image
    /// (feed slides, story page).
    var plates: [Artwork] { (Self.platesByStory[id] ?? []).map(\.artwork) }

    private static let platesByStory: [Story.ID: [GodPlate]] = [
        "delphi": [.apolloSun, .apolloOrbs, .apolloLight],          // Apollo's oracle
        "sounion": [.poseidonStorm, .poseidonCrown],                // Poseidon's temple
        "knossos": [.poseidonArcher],                               // Poseidon's white bull
        "zeus": [.zeusLaurel, .poseidonCrown],                      // Zeus — or Poseidon?
        "olympia": [.zeusEagle, .zeusWings],                        // Zeus's sanctuary
        "mycenae": [.aresBattle, .aresArmor],                       // a citadel of war
        "agamemnon": [.aresPortrait],                               // the warrior king
        // Myths retold from Berens
        "birth-of-zeus": [.zeusEagle, .zeusWings],
        "apollo-daphne": [.apolloLight, .apolloSun],
        "niobe": [.artemisHunt, .apolloOrbs],                       // Artemis and Apollo
        "birth-of-aphrodite": [.aphrodite],
        "poseidon-deep": [.poseidonCrown, .poseidonArcher],
        "hill-of-ares": [.aresPortrait, .aresArmor],
        "phaethon": [.apolloLight],                                 // the sun's light
        "persephone": [.zeusLaurel],                                // the Zeus who allowed it
    ]
}
