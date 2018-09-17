module Hacl.Impl.Aes.Generic

module ST = FStar.HyperStack.ST
open FStar.HyperStack
open FStar.HyperStack.All
open Lib.IntTypes
open LowStar.Buffer
open Lib.Utils
open Hacl.Impl.Aes.Core

(* Parameters for AES-128 *)
noextract inline_for_extraction let nb =  4
noextract inline_for_extraction let nk =  4 // 4, 6, or 8 for 128/192/256
noextract inline_for_extraction let nr =  10 // 10, 12, or 14 for 128/192/256

type skey  = lbytes 16
type skey256  = lbytes 32

inline_for_extraction
let ctxlen (m:m_spec) =  nlen m + (15 `op_Multiply` klen m)

type keyr (m:m_spec) =  lbuffer (stelem m) (9 `op_Multiply` klen m)
type keyex (m:m_spec) = lbuffer (stelem m) (15 `op_Multiply` klen m) // Saving space for AES-256
type aes_ctx (m:m_spec) = lbuffer (stelem m) (ctxlen m) 

inline_for_extraction
let get_nonce (#m:m_spec) (ctx:aes_ctx m) = sub ctx (size 0) (size (nlen m))
inline_for_extraction
let get_kex (#m:m_spec) (ctx:aes_ctx m) = sub ctx (size (nlen m)) (size 15 
*. size (klen m))

inline_for_extraction
let create_ctx (m:m_spec) = create (elem_zero m) (size (ctxlen m))

inline_for_extraction
val add_round_key: #m:m_spec -> st:state m -> key:key1 m -> ST unit
			     (requires (fun h -> live h st /\ live h key))
			     (ensures (fun h0 _ h1 -> live h1 st /\ live h1 key /\ modifies (loc_buffer st) h0 h1))
let add_round_key #m st key = xor_state_key1 st key

//[@ CInline ]
inline_for_extraction
val enc_rounds: #m:m_spec -> st:state m -> key:keyr m -> n:size_t -> ST unit
	     (requires (fun h -> live h st /\ live h key))
	     (ensures (fun h0 _ h1 -> live h1 st /\ live h1 key /\ modifies (loc_buffer st) h0 h1))
[@ CInline ]
let enc_rounds #m st key n = 
    let h0 = ST.get() in
    loop_nospec #h0 n st 
      (fun i -> let sub_key = sub key i (size (klen m)) in aes_enc st sub_key)


inline_for_extraction
val block_cipher: #m:m_spec -> st:state m -> key:keyex m -> n:size_t -> ST unit
	     (requires (fun h -> live h st /\ live h key))
	     (ensures (fun h0 _ h1 -> live h1 st /\ live h1 key /\ modifies (loc_buffer st) h0 h1))
let block_cipher #m st key n = 
    let inner_rounds = n -. size 1 in
    let klen = size (klen m) in
    let k0 = sub key (size 0) klen in
    let kr = sub key (size 1) (inner_rounds *. klen) in
    let kn = sub key (size 10) klen in
    add_round_key st k0;
    enc_rounds st kr (n -. size 1);
    aes_enc_last st kn


let rcon =  gcreateL [u8(0x8d); u8(0x01); u8(0x02); u8(0x04); u8(0x08); u8(0x10); u8(0x20); u8(0x40); u8(0x80); u8(0x1b); u8(0x36)]


//[@ CInline ]
inline_for_extraction
val key_expansion128: #m:m_spec -> keyx:keyex m -> key:lbytes 16 -> ST unit
			     (requires (fun h -> live h keyx /\ live h key))
			     (ensures (fun h0 _ h1 -> live h1 keyx /\ live h1 key /\ modifies (loc_buffer keyx) h0 h1))
[@ CInline ]
let key_expansion128 #m keyx key = 
    load_key1 (sub keyx (size 0) (size (klen m))) key;
    let h0 = ST.get() in
    (* I WOULD LIKE TO HAVE A LOOP HERE BUT AES_KEYGEN_ASSIST INSISTS ON AN IMMEDIATE RCON *)
    (* MAYBE WE SHOULD UNROLL ONLY THIS LOOP *)
    (* loop_nospec #h0 (size 10) keyx 
    (fun i -> 
       let prev = sub keyx i (size 1) in
       let next = sub keyx (i +. size 1) (size 1) in
       aes_keygen_assist next rcon.(i +. size 1);
       key_expansion_step next prev)
		     *)
       let prev = sub keyx (size 0) (size 1) in
       let next = sub keyx (size 1) (size 1) in
       aes_keygen_assist next prev (u8 0x01);
       key_expansion_step next prev;
       let prev = sub keyx (size 1) (size 1) in
       let next = sub keyx (size 2) (size 1) in
       aes_keygen_assist next prev (u8 0x02);
       key_expansion_step next prev;
       let prev = sub keyx (size 2) (size 1) in
       let next = sub keyx (size 3) (size 1) in
       aes_keygen_assist next prev (u8 0x04);
       key_expansion_step next prev;
       let prev = sub keyx (size 3) (size 1) in
       let next = sub keyx (size 4) (size 1) in
       aes_keygen_assist next prev (u8 0x08);
       key_expansion_step next prev;
       let prev = sub keyx (size 4) (size 1) in
       let next = sub keyx (size 5) (size 1) in
       aes_keygen_assist next prev (u8 0x10);
       key_expansion_step next prev;
       let prev = sub keyx (size 5) (size 1) in
       let next = sub keyx (size 6) (size 1) in
       aes_keygen_assist next prev (u8 0x20);
       key_expansion_step next prev;
       let prev = sub keyx (size 6) (size 1) in
       let next = sub keyx (size 7) (size 1) in
       aes_keygen_assist next prev (u8 0x40);
       key_expansion_step next prev;
       let prev = sub keyx (size 7) (size 1) in
       let next = sub keyx (size 8) (size 1) in
       aes_keygen_assist next prev (u8 0x80);
       key_expansion_step next prev;
       let prev = sub keyx (size 8) (size 1) in
       let next = sub keyx (size 9) (size 1) in
       aes_keygen_assist next prev (u8 0x1b);
       key_expansion_step next prev;
       let prev = sub keyx (size 9) (size 1) in
       let next = sub keyx (size 10) (size 1) in
       aes_keygen_assist next prev (u8 0x36);
       key_expansion_step next prev
       

val key_expansion256: #m:m_spec -> keyx:keyex m -> key:lbytes 32 -> ST unit
			     (requires (fun h -> live h keyx /\ live h key))
			     (ensures (fun h0 _ h1 -> live h1 keyx /\ live h1 key /\ modifies (loc_buffer keyx) h0 h1))
let key_expansion256 #m keyx key = 
    load_key1 (sub keyx (size 0) (size (klen m))) (sub key (size 0) (size 16));
    load_key1 (sub keyx (size (klen m)) (size (klen m))) (sub key (size 16) (size 16));
    let h0 = ST.get() in
    (* I WOULD LIKE TO HAVE A LOOP HERE BUT AES_KEYGEN_ASSIST INSISTS ON AN IMMEDIATE RCON *)
    (* MAYBE WE SHOULD UNROLL ONLY THIS LOOP *)
       let prev0 = sub keyx (size 0) (size 1) in
       let prev1 = sub keyx (size 1) (size 1) in
       let next0 = sub keyx (size 2) (size 1) in
       let next1 = sub keyx (size 3) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x01);
       key_expansion_step next0 prev0;
       aes_keygen_assist next1 next0 (u8 0x00);
       key_expansion_step2 next1 prev1;
       let prev0 = next0 in
       let prev1 = next1 in
       let next0 = sub keyx (size 4) (size 1) in
       let next1 = sub keyx (size 5) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x02);
       key_expansion_step next0 prev0;
       aes_keygen_assist next1 next0 (u8 0x00);
       key_expansion_step2 next1 prev1;
       let prev0 = next0 in
       let prev1 = next1 in
       let next0 = sub keyx (size 6) (size 1) in
       let next1 = sub keyx (size 7) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x04);
       key_expansion_step next0 prev0;
       aes_keygen_assist next1 next0 (u8 0x00);
       key_expansion_step2 next1 prev1;
       let prev0 = next0 in
       let prev1 = next1 in
       let next0 = sub keyx (size 8) (size 1) in
       let next1 = sub keyx (size 9) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x08);
       key_expansion_step next0 prev0;
       aes_keygen_assist next1 next0 (u8 0x00);
       key_expansion_step2 next1 prev1;
       let prev0 = next0 in
       let prev1 = next1 in
       let next0 = sub keyx (size 10) (size 1) in
       let next1 = sub keyx (size 11) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x10);
       key_expansion_step next0 prev0;
       aes_keygen_assist next1 next0 (u8 0x00);
       key_expansion_step2 next1 prev1;
       let prev0 = next0 in
       let prev1 = next1 in
       let next0 = sub keyx (size 12) (size 1) in
       let next1 = sub keyx (size 13) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x20);
       key_expansion_step next0 prev0;
       aes_keygen_assist next1 next0 (u8 0x00);
       key_expansion_step2 next1 prev1;
       let prev0 = next0 in
       let prev1 = next1 in
       let next0 = sub keyx (size 14) (size 1) in
       aes_keygen_assist next0 prev1 (u8 0x40);
       key_expansion_step next0 prev0
    

inline_for_extraction
val aes128_init: #m:m_spec -> ctx:aes_ctx m -> key:skey -> nonce:lbytes 12 -> ST unit
			     (requires (fun h -> live h ctx /\ live h nonce /\ live h key))
			     (ensures (fun h0 b h1 -> modifies (loc_buffer ctx) h0 h1))
let aes128_init #m ctx key nonce = 
  let kex = get_kex ctx in
  let n = get_nonce ctx in
  key_expansion128 kex key ; 
  load_nonce #m n nonce

inline_for_extraction
val aes256_init: #m:m_spec -> ctx:aes_ctx m -> key:skey -> nonce:lbytes 12 -> ST unit
			     (requires (fun h -> live h ctx /\ live h nonce /\ live h key))
			     (ensures (fun h0 b h1 -> modifies (loc_buffer ctx) h0 h1))
let aes256_init #m ctx key nonce = 
  let kex = get_kex ctx in
  let n = get_nonce ctx in
  key_expansion256 kex key ; 
  load_nonce #m n nonce


inline_for_extraction
val aes128_key_block: #m:m_spec -> kb:lbytes 16 -> ctx:aes_ctx m -> counter:size_t -> ST unit
			     (requires (fun h -> live h kb /\ live h ctx))
			     (ensures (fun h0 _ h1 -> modifies (loc_buffer kb) h0 h1))
let aes128_key_block #m kb ctx counter = 
    push_frame();
    let kex = get_kex ctx in
    let n = get_nonce ctx in
    let st = create_state #m in
    load_state st n counter;
    block_cipher st kex (size 10);
    store_block0 kb st;
    pop_frame()
    


inline_for_extraction
val aes_update4: #m:m_spec -> out:lbytes 64 -> inp:lbytes 64 -> ctx:aes_ctx m -> counter:size_t -> rounds:size_t -> ST unit
			     (requires (fun h -> live h out /\ live h inp /\ live h ctx))
			     (ensures (fun h0 b h1 -> modifies (loc_buffer out) h0 h1))
let aes_update4 #m out inp ctx ctr rounds =
  push_frame();
  let st = create_state #m in
  let kex = get_kex ctx in
  let n = get_nonce ctx in
  load_state st n ctr;
  block_cipher st kex rounds;
  xor_block out st inp;
  pop_frame()

inline_for_extraction
val aes_ctr: #m:m_spec -> out:bytes -> inp:bytes -> len:size_t -> ctx:aes_ctx m -> counter:size_t -> rounds:size_t -> ST unit
			     (requires (fun h -> live h out /\ live h inp /\ live h ctx))
			     (ensures (fun h0 _ h1 -> modifies (loc_buffer out) h0 h1))
let aes_ctr #m out inp len ctx counter rounds = 
  push_frame();
  let blocks64 = len /. size 64 in
  let h0 = ST.get() in
  loop_nospec #h0 blocks64 out 
    (fun i -> 
      let ctr = counter +. (i *. size 4) in
      let ib = sub inp (i *. size 64) (size 64) in
      let ob = sub out (i *. size 64) (size 64) in
      aes_update4 ob ib ctx ctr rounds);
  let rem = len %. size 64 in
  if (rem >. size 0) then (
      let ctr = counter +. (blocks64 *. size 4) in
      let ib = sub inp (blocks64 *. size 64) rem in
      let ob = sub out (blocks64 *. size 64) rem in
      let last = alloca 0uy 64ul in
      blit ib (size 0) last (size 0) rem;
      aes_update4 last last ctx ctr rounds;
      blit last (size 0) ob (size 0) rem);
  pop_frame()

inline_for_extraction
let aes128_ctr_encrypt (#m:m_spec) out inp in_len k n c = 
  push_frame();
  let ctx = create_ctx m in
  aes128_init ctx k n;
  aes_ctr out inp in_len ctx c (size 10);
  pop_frame()

inline_for_extraction
let aes128_ctr_decrypt (#m:m_spec) out inp in_len k n c = 
  aes128_ctr_encrypt #m out inp in_len k n c

inline_for_extraction
let aes256_ctr_encrypt (#m:m_spec) out inp in_len k n c = 
  push_frame();
  let ctx = create_ctx m in
  aes256_init ctx k n;
  aes_ctr out inp in_len ctx c (size 14);
  pop_frame()

inline_for_extraction
let aes256_ctr_decrypt (#m:m_spec) out inp in_len k n c = 
  aes128_ctr_encrypt #m out inp in_len k n c
