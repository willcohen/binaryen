#include <cassert>
#include <iostream>

#include <cfg/dominates.h>
#include <ir/effects.h>
#include <wasm.h>

using namespace wasm;

struct BasicBlock {
  std::vector<BasicBlock*> in;

  struct Contents {
    std::vector<Expression*> list;
  } contents;

  void addPred(BasicBlock* pred) { in.push_back(pred); }

  Expression* addItem(Expression* item) {
    contents.list.push_back(item);
    return item;
  }
};

struct CFG : public std::vector<std::unique_ptr<BasicBlock>> {
  BasicBlock* add() {
    emplace_back(std::make_unique<BasicBlock>());
    return back().get();
  }

  void connect(BasicBlock* pred, BasicBlock* succ) { succ->addPred(pred); }
};

void test_dominates() {
  Module temp;
  Builder builder(temp);

// Do a check of
//
//   assert( check(left, right) );
//
// and also check the reverse (right, left) combination. If left == right then
// that must assert as true, the same as unflipped. Otherwise, it must check
// as the reverse, as domination of different items is antisymmetrical.
#define CHECK_TRUE(check, left, right)                                         \
  {                                                                            \
    assert(check(left, right));                                                \
    if (left == right) {                                                       \
      assert(check(right, left));                                              \
    } else {                                                                   \
      assert(!check(right, left));                                             \
    }                                                                          \
  }

// As above, but check that the result is false for both (left, right) and
// (right, left). This is the case for two blocks where neither dominates the
// other.
#define CHECK_FALSE(check, left, right)                                        \
  {                                                                            \
    assert(!check(left, right));                                               \
    assert(!check(right, left));                                               \
  }

  // An CFG with just an entry.
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* first = entry->addItem(builder.makeNop());
    auto* second = entry->addItem(builder.makeNop());
    auto* third = entry->addItem(builder.makeNop());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    // Things dominate themselves.
    CHECK_TRUE(checker.dominates, first, first);
    CHECK_TRUE(checker.dominates, second, second);
    CHECK_TRUE(checker.dominates, third, third);

    // Things dominate those after them.
    CHECK_TRUE(checker.dominates, first, second);
    CHECK_TRUE(checker.dominates, first, third);
    CHECK_TRUE(checker.dominates, second, third);
  }

  // entry => next, with items in both.
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* next = cfg.add();
    cfg.connect(entry, next);
    auto* entryA = entry->addItem(builder.makeNop());
    auto* entryB = entry->addItem(builder.makeNop());
    auto* nextA = next->addItem(builder.makeNop());
    auto* nextB = next->addItem(builder.makeNop());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    // Things dominate themselves in all blocks.
    CHECK_TRUE(checker.dominates, entryA, entryA);
    CHECK_TRUE(checker.dominates, entryB, entryB);
    CHECK_TRUE(checker.dominates, nextA, nextA);
    CHECK_TRUE(checker.dominates, nextB, nextB);

    // Things dominate things after them in the same block.
    CHECK_TRUE(checker.dominates, entryA, entryB);
    CHECK_TRUE(checker.dominates, nextA, nextB);

    // The entry block items dominate items in the next block.
    CHECK_TRUE(checker.dominates, entryA, nextA);
    CHECK_TRUE(checker.dominates, entryA, nextB);
    CHECK_TRUE(checker.dominates, entryB, nextA);
    CHECK_TRUE(checker.dominates, entryB, nextB);
  }

  // Domination with an intermediate block, entry => middle => last
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* middle = cfg.add();
    auto* last = cfg.add();
    cfg.connect(entry, middle);
    cfg.connect(middle, last);
    auto* entryA = entry->addItem(builder.makeNop());
    auto* middleA = middle->addItem(builder.makeNop());
    auto* lastA = last->addItem(builder.makeNop());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    CHECK_TRUE(checker.dominates, entryA, middleA);
    CHECK_TRUE(checker.dominates, entryA, lastA);
    CHECK_TRUE(checker.dominates, middleA, lastA);
  }

  // An if:
  //            b
  //           / \
  // entry -> a   d
  //           \ /
  //            c
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* a = cfg.add();
    auto* b = cfg.add();
    auto* c = cfg.add();
    auto* d = cfg.add();
    cfg.connect(entry, a);
    cfg.connect(a, b);
    cfg.connect(a, c);
    cfg.connect(b, d);
    cfg.connect(c, d);
    auto* aX = a->addItem(builder.makeNop());
    auto* bX = b->addItem(builder.makeNop());
    auto* cX = c->addItem(builder.makeNop());
    auto* dX = d->addItem(builder.makeNop());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    // a dominates all the others.
    CHECK_TRUE(checker.dominates, aX, bX);
    CHECK_TRUE(checker.dominates, aX, cX);
    CHECK_TRUE(checker.dominates, aX, dX);

    // b, c, and d do not dominate amongst each other.
    CHECK_FALSE(checker.dominates, bX, cX);
    CHECK_FALSE(checker.dominates, bX, dX);
    CHECK_FALSE(checker.dominates, cX, dX);
  }

#undef CHECK_TRUE
#undef CHECK_FALSE
}

void test_dominates_without_interference() {
  Module temp;
  Builder builder(temp);
  PassOptions options;

// Do a check of
//
//   assert( check(left, right) );
//
// and also check the reverse (right, left) combination. If left == right then
// that must assert as true, the same as unflipped. Otherwise, it must check
// as the reverse, as domination of different items is antisymmetrical.
#define CHECK_TRUE(check, left, right, effects, ignore)                                         \
  {                                                                            \
    assert(check(left, right, effects, ignore, temp, options));                                                \
    if (left == right) {                                                       \
      assert(check(right, left, effects, ignore, temp, options));                                              \
    } else {                                                                   \
      assert(!check(right, left, effects, ignore, temp, options));                                             \
    }                                                                          \
  }

// As above, but check that the result is false for both (left, right) and
// (right, left). This is the case for two blocks where neither dominates the
// other.
#define CHECK_FALSE(check, left, right, effects, ignore)                                        \
  {                                                                            \
    assert(!check(left, right, effects, ignore, temp, options));                                               \
    assert(!check(right, left, effects, ignore, temp, options));                                               \
  }

  auto noEffects = EffectAnalyzer(options, temp);

  auto sideEffects = EffectAnalyzer(options, temp);
  sideEffects.calls = true;

  auto makeNop = [&]() {
    return builder.makeNop();
  };

  // An CFG with just an entry, and nothing has side effects.
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* first = entry->addItem(makeNop());
    auto* second = entry->addItem(makeNop());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    // Things dominate themselves without interference
    CHECK_TRUE(checker.dominatesWithoutInterference, first, first, noEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, second, second, noEffects, {});

    // And the first dominates the second too.
    CHECK_TRUE(checker.dominatesWithoutInterference, first, second, noEffects, {});
  }

  auto makeSideEffects = [&]() {
    return builder.makeCall("something", {}, Type::i32);
  };

  // As above, but now both have side effects. However, there is nothing in
  // between them, so there is no problem.
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* first = entry->addItem(makeSideEffects());
    auto* second = entry->addItem(makeSideEffects());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    CHECK_TRUE(checker.dominatesWithoutInterference, first, first, sideEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, second, second, sideEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, first, second, sideEffects, {});
  }

  // Add a side effect in the middle.
  {
    CFG cfg;
    auto* entry = cfg.add();
    auto* first = entry->addItem(makeNop());
    auto* second = entry->addItem(makeSideEffects());
    auto* third = entry->addItem(makeNop());

    cfg::DominationChecker<BasicBlock> checker(cfg);

    // Identical or adjacent things are still fine.
    CHECK_TRUE(checker.dominatesWithoutInterference, first, first, sideEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, second, second, sideEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, third, third, sideEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, first, second, sideEffects, {});
    CHECK_TRUE(checker.dominatesWithoutInterference, second, third, sideEffects, {});

    // But first has interference on the way to dominate third.
    CHECK_FALSE(checker.dominatesWithoutInterference, first, third, sideEffects, {});

    // If we replace sideEffects with noEffects then things are ok again.
    CHECK_TRUE(checker.dominatesWithoutInterference, first, third, noEffects, {});

    // If we ignore the middle item then things are also ok again.
    CHECK_FALSE(checker.dominatesWithoutInterference, first, third, sideEffects, {second});
  }

  // TODO: more effects at start and end of block
}

int main() {
  test_dominates();
  test_dominates_without_interference();
  std::cout << "success.\n";
}