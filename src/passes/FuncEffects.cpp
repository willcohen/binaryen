/*
 * Copyright 2021 WebAssembly Community Group participants
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
// Operations on Stack IR.
//

#include "ir/module-utils.h"
#include "pass.h"
#include "wasm.h"

namespace wasm {

// Generate Stack IR from Binaryen IR

struct GenerateFuncEffects : public WalkerPass<PostWalker<GenerateFuncEffects>> {
  virtual void run(PassRunner* runner, Module* module) {
    struct Info {
    };

    ParallelFunctionAnalysis<Info> analysis(*module, [&](Function* func, Info& info) {
    });

  }
};

struct DiscardFuncEffects : public Pass {
  virtual void run(PassRunner* runner, Module* module) {
    runner->options.funcEffects.clear();
  }
};

Pass* createGenerateFuncEffectsPass() { return new GenerateFuncEffects(); }

Pass* createDiscardFuncEffectsPass() { return new DiscardFuncEffects(); }

} // namespace wasm
