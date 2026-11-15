// Copyright 2026 Courville Software
// SPDX-License-Identifier: Apache-2.0

#include "fasttext.h"

#include <exception>
#include <iostream>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "Usage: fasttext_smoke MODEL\n";
        return 2;
    }
    try {
        fasttext::FastText model;
        model.loadModel(argv[1]);
        const std::pair<const char*, const char*> samples[] = {
            {"en", "We should leave the house before the rain starts. "
                   "Please bring your coat and remember to close the windows. "
                   "I will wait for you at the station tomorrow morning."},
            {"fr", "Nous devons quitter la maison avant le début de la pluie. "
                   "N'oublie pas ton manteau et ferme les fenêtres avant de partir. "
                   "Je t'attendrai demain matin devant la gare."},
        };
        for (const auto& sample : samples) {
            std::istringstream input(sample.second);
            std::vector<std::pair<fasttext::real, std::string>> predictions;
            const std::string expected = std::string("__label__") + sample.first;
            if (!model.predictLine(input, predictions, 2, 0.0f) || predictions.empty() ||
                predictions[0].second != expected || predictions[0].first < 0.8f) {
                std::cerr << "Language identification failed for " << sample.first << '\n';
                return 1;
            }
            std::cout << sample.first << ": " << predictions[0].first << '\n';
        }
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
    return 0;
}
