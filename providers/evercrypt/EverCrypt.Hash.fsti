module EverCrypt.Hash

open EverCrypt.Helpers
open FStar.HyperStack.ST
open FStar.Integers

module HS = FStar.HyperStack
module B = LowStar.Buffer
module M = LowStar.Modifies
module G = FStar.Ghost

open LowStar.BufferOps

type alg =
| SHA256
| SHA384

type e_alg =
  G.erased alg

val state_s: e_alg -> Type0
let state alg = B.pointer (state_s alg)

// NS: note that the state is the first argument to the invariant so that we can
// do partial applications in pre- and post-conditions
val footprint_s: #a:e_alg -> state_s a -> GTot M.loc
let footprint (#a: e_alg) (s: state a) (m: HS.mem) =
  M.(loc_union (loc_buffer s) (footprint_s (deref m s)))

val invariant_s: (#a: e_alg) -> state_s a -> HS.mem -> Type0
let invariant (#a: e_alg) (s: state a) (m: HS.mem) =
  B.live m s /\
  M.(loc_disjoint (loc_buffer s) (footprint_s (deref m s))) /\
  invariant_s (B.get m s 0) m

let type_of alg =
  match G.reveal alg with
  | SHA256 -> uint_32
  | SHA384 -> uint_64

let size_of_k alg =
  match G.reveal alg with
  | SHA256 -> 64
  | SHA384 -> 80

type repr_t (a: e_alg) = {
  k: Seq.lseq (type_of a) (size_of_k a);
  hash: Seq.lseq (type_of a) 8;
  counter: nat;
}

val repr: #a:e_alg -> s:state a -> h:HS.mem { invariant s h } ->
  GTot (repr_t a)

// Waiting for these to land in LowStar.Modifies
let loc_in (l: M.loc) (h: HS.mem) =
  M.(loc_not_unused_in h `loc_includes` l)

let loc_unused_in (l: M.loc) (h: HS.mem) =
  M.(loc_unused_in h `loc_includes` l)

let fresh_loc (l: M.loc) (h0 h1: HS.mem) =
  loc_unused_in l h0 /\ loc_in l h1

val fresh_is_disjoint: l1:M.loc -> l2:M.loc -> h0:HS.mem -> h1:HS.mem -> Lemma
  (requires (fresh_loc l1 h0 h1 /\ l2 `loc_in` h0))
  (ensures (M.loc_disjoint l1 l2))

val frame_invariant: #a:e_alg -> l:M.loc -> s:state a -> h0:HS.mem -> h1:HS.mem -> Lemma
  (requires (
    invariant s h0 /\
    M.loc_disjoint l (footprint s h0) /\
    M.modifies l h0 h1))
  (ensures (
    invariant s h1 /\
    repr s h0 == repr s h1))

let frame_invariant_implies_footprint_preservation
  (#a: e_alg)
  (l: M.loc)
  (s: state a)
  (h0 h1: HS.mem): Lemma
  (requires (
    invariant s h0 /\
    M.loc_disjoint l (footprint s h0) /\
    M.modifies l h0 h1))
  (ensures (
    footprint s h1 == footprint s h0))
=
  ()

val create: a:alg -> ST (state (G.hide a))
  (requires fun h0 -> True)
  (ensures fun h0 s h1 ->
    invariant s h1 /\
    M.(modifies loc_none h0 h1) /\
    fresh_loc (footprint s h1) h0 h1)

let init_repr (a: e_alg): GTot (repr_t a) =
  match G.reveal a with
  | SHA256 -> {
      hash = EverCrypt.Spec.SHA2_256.h_0;
      k = EverCrypt.Spec.SHA2_256.k;
      counter = 0
    }
  | SHA384 -> {
      hash = EverCrypt.Spec.SHA2_384.h_0;
      k = EverCrypt.Spec.SHA2_384.k;
      counter = 0
    }

val init: #a:e_alg -> s:state a -> ST unit
  (requires (invariant s))
  (ensures (fun h0 _ h1 ->
    invariant s h1 /\
    M.(modifies (footprint s h0) h0 h1) /\
    footprint s h0 == footprint s h1 /\
    repr s h1 == init_repr a))
