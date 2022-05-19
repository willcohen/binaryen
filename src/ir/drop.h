/*
 * Copyright 2022 WebAssembly Community Group participants
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

#ifndef wasm_ir_drop_h
#define wasm_ir_drop_h

#include "ir/effects.h"
#include "ir/iteration.h"
#include "wasm-builder.h"
#include "wasm.h"

namespace wasm {

// Returns the dropped children of a node (in a block, if there is more than
// one). This is useful if we know the node is not needed but may need to keep
// the children around; this utility will automatically remove any children we
// do not actually need to keep, based on their effects.
//
// The caller can also pass in an optional last item to add to the output.
Expression* getDroppedChildren(Expression* curr,
                               Module& wasm,
                               const PassOptions& options,
                               Expression* last = nullptr) {
  Builder builder(wasm);
  std::vector<Expression*> contents;
  for (auto* child : ChildIterator(curr)) {
    if (!EffectAnalyzer(options, wasm, child).hasUnremovableSideEffects()) {
      continue;
    }
    if (child->type.isConcrete()) {
      contents.push_back(builder.makeDrop(child));
    } else {
      // The child is unreachable, or none (none is possible as a child of a
      // block or loop, etc.); in both cases we do not need a drop.
      contents.push_back(child);
    }
  }
  if (last) {
    contents.push_back(last);
  }
  if (contents.size() == 0) {
    return builder.makeNop();
  }
  if (contents.size() == 1) {
    return contents[0];
  }
  return builder.makeBlock(contents);
}

} // namespace wasm

#endif // wasm_ir_drop_h