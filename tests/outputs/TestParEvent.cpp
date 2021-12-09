//
// Copyright (c) 2021, RTE (http://www.rte-france.com)
// See AUTHORS.txt
// All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at http://mozilla.org/MPL/2.0/.
// SPDX-License-Identifier: MPL-2.0
//

#include "Contingencies.h"
#include "ParEvent.h"
#include "Tests.h"

#include <boost/filesystem.hpp>

testing::Environment* initXmlEnvironment();

testing::Environment* const env = initXmlEnvironment();

TEST(TestParEvent, write) {
  using ContingencyElement = dfl::inputs::ContingencyElement;
  using ElementType = dfl::inputs::ContingencyElement::Type;

  std::string basename = "TestParEvent";
  std::string dirname = "results";
  std::string filename = basename + ".par";

  boost::filesystem::path outputPath(dirname);
  outputPath.append(basename);

  if (!boost::filesystem::exists(outputPath)) {
    boost::filesystem::create_directory(outputPath);
  }

  auto contingency = dfl::inputs::Contingency("TestContingency");
  // We need the three of them to check the three cases that can be generated
  contingency.elements.emplace_back("TestBranch", ElementType::BRANCH);                       // buildBranchDisconnection (branch case)
  contingency.elements.emplace_back("TestGenerator", ElementType::GENERATOR);                 // buildEventSetPointBooleanDisconnection
  contingency.elements.emplace_back("TestShuntCompensator", ElementType::SHUNT_COMPENSATOR);  // buildEventSetPointBooleanDisconnection
  contingency.elements.emplace_back("TestLine", ElementType::LINE);                           // buildEventSetPointRealDisconnection (general case)

  outputPath.append(filename);
  dfl::outputs::ParEvent par(dfl::outputs::ParEvent::ParEventDefinition(basename, outputPath.generic_string(), contingency, std::chrono::seconds(80)));
  par.write();

  boost::filesystem::path reference("reference");
  reference.append(basename);
  reference.append(filename);

  dfl::test::checkFilesEqual(outputPath.generic_string(), reference.generic_string());
}
