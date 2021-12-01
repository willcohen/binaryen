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
    using Info = std::shared_ptr<EffectAnalyzer>;

    // Create a single Info to represent "anything" - any effect might happen,
    // and we give up on trying to analyze things. To represent that, mark it as
    // doing a call (which could do anything in the called code). Note that this
    // does not say anything about effects on locals on the stack, which is
    // intentional - we will use this as the effects of a call, which indeed
    // cannot have such effects.
    Info anything = std::make_shared<EffectAnalyzer>(runner->options, *module);
    anything->calls = true;

    ParallelFunctionAnalysis<Info> analysis(*module, [&](Function* func, Info& info) {
      if (func->imported()) {
        // Imported functions can do anything.
        info = anything;
      } else {
        // For defined functions, compute the effects in their body.
        info = std::make_shared<EffectAnalyzer>(runner->options, *module, func->body);

        // Discard any effects on locals, since those are not noticeable in the
        // caller.
        info->localsWritten.clear();
        info->localsRead.clear();
      }
    });

    // TODO: Propagate effects through direct calls. Without that we only look
    //       one call deep, basically.

    // Copy the info to the final location.
    auto& funcEffects = runner->options.funcEffects;
    funcEffects.clear();
    for (auto& [func, info] : analysis.map) {
      funcEffects[func->name] = info;
    }
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
