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
    // First, clear any previous function effects. We don't want to notice them
    // when we compute effects here.
    auto& funcEffects = runner->options.funcEffects;
    funcEffects.clear();

    using Info = std::shared_ptr<EffectAnalyzer>;

    // Create a single Info to represent "anything" - any effect might happen,
    // and we give up on trying to analyze things. To represent that, scan a
    // fake call (running the actual effect analyzer code on a call is important
    // so that it picks up things like possibly throwing if exceptions are
    // enabled, etc.). Note that this
    // does not say anything about effects on locals on the stack, which is
    // intentional - we will use this as the effects of a call, which indeed
    // cannot have such effects.
    Call fakeCall(module->allocator);
    Info anything = std::make_shared<EffectAnalyzer>(runner->options, *module, &fakeCall);

    ModuleUtils::ParallelFunctionAnalysis<Info> analysis(*module, [&](Function* func, Info& info) {
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

        // Discard branching out of an expression or a return - we are returning
        // back out to the caller anyhow. (If this is a return_call then we do
        // need this property, but it will be added when computing effects:
        // visitCall() in effects.h will add our effects as computed here, and
        // then also take into account return_call effects as well.)
        info->branchesOut = false;

        // As we have parsed an entire function, there should be no structural
        // info about being inside a try-catch.
        assert(!info->tryDepth);
        assert(!info->catchDepth);
        assert(!info->danglingPop);
      }
    });

    // TODO: Propagate effects through direct calls. Without that we only look
    //       one call deep, basically.
    //       The propagation can use the identity of |anything| for convenience
    //       (to indicate "we've failed to learn anything here").

    // TODO: share the Info object between functions where possible to save
    //       memory, like we do with |anything| already.

    // Copy the info to the final location.
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
