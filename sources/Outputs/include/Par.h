//
// Copyright (c) 2020, RTE (http://www.rte-france.com)
// See AUTHORS.txt
// All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at http://mozilla.org/MPL/2.0/.
// SPDX-License-Identifier: MPL-2.0
//

/**
 * @file  Par.h
 *
 * @brief Dynaflow launcher PAR file writer header file
 *
 */

#pragma once

#include "Algo.h"

#include <PARParametersSet.h>
#include <boost/shared_ptr.hpp>
#include <functional>
#include <string>
#include <unordered_map>
#include <vector>

namespace dfl {
namespace outputs {
/**
 * @brief PAR file writer
 */
class Par {
 public:
  /**
   * @brief PAR file definition
   */
  struct ParDefinition {
    /**
     * @brief Constructor
     *
     * @param base basename for current simulation
     * @param filename file path for output PAR file (corresponds to basename)
     * @param gens list of the generators taken into account
     */
    ParDefinition(const std::string& base, const std::string& filename, const std::vector<algo::GeneratorDefinition>& gens) :
        basename{base},
        filepath{filename},
        generators{gens} {}

    std::string basename;                               ///< basename
    std::string filepath;                               ///< file path of the output file to write
    std::vector<algo::GeneratorDefinition> generators;  ///< list of generators
  };

  /**
   * @brief Constructor
   *
   * @param def PAR file definition
   */
  explicit Par(ParDefinition&& def);

  /**
   * @brief Export PAR file
   */
  void write();

 private:
  /**
    * @brief Write constants parameter sets
    *
    * @param nb_generators total number of generators taken into account
    *
    * @returns list of generated parameter sets
    */
  static std::vector<boost::shared_ptr<parameters::ParametersSet>> writeConstantSets(unsigned int nb_generators);

  /**
   * @brief Update parameter set with SignalN generator parameters and references
   *
   * @param set the parameter set to update
   */
  static void updateSignalNGenerator(boost::shared_ptr<parameters::ParametersSet> set);

  /**
   * @brief Update parameter set with impendance model parameters and references
   *
   * @param set the parameter set to update
   */
  static void updateCouplingParameters(boost::shared_ptr<parameters::ParametersSet> set);

  /**
   * @brief Write generator parameter set
   *
   * @param def the generator definition to use
   * @param basename the basename for the simulation
   *
   * @returns nullptr if the generator use a SignalN model, the parameter set if not
   */
  static boost::shared_ptr<parameters::ParametersSet> writeGenerator(const algo::GeneratorDefinition& def, const std::string& basename);

 private:
  ParDefinition def_;  ///< PAR file definition
};

}  // namespace outputs
}  // namespace dfl
