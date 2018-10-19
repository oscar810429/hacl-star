module Hacl.Impl.AesGCM
module ST = FStar.HyperStack.ST
open FStar.HyperStack
open FStar.HyperStack.All
open Lib.IntTypes
open LowStar.Buffer
open Lib.Utils
open Lib.Vec128
open Hacl.Impl.Aes.NI
open Hacl.Impl.Gf128.NI

[@ CInline ]
val aes128_gcm_encrypt: out:bytes -> text:bytes -> len:size_t{length text == size_v len} -> 
			aad:bytes -> aad_len:size_t{length aad == size_v aad_len} ->
			key:lbytes 16 -> nonce:lbytes 12 -> Stack unit
	  (requires (fun h -> live h out /\ live h text /\ live h aad /\ live h key /\ live h nonce))
	  (ensures (fun h0 _ h1 -> modifies (loc_buffer out) h0 h1))
[@ CInline ]
let aes128_gcm_encrypt out text len aad aad_len key nonce =
    push_frame();
    let gcm_key = alloca 0uy 16ul in
    let tag_mix = alloca 0uy 16ul in
    let nonce0 = alloca 0uy 12ul in
    let ctx = create_ctx () in
    aes128_init ctx key nonce0;
    aes128_key_block gcm_key ctx (size 0);
    aes128_set_nonce ctx nonce;
    aes128_key_block tag_mix ctx (size 1);
    let (acc,r4) = gcm_alloc () in
    gcm_init acc r4 gcm_key;  

    let cip = sub out (size 0) len in
    aes_ctr cip text len ctx (size 2) (size 10);
    poly4 acc aad aad_len r4;
    poly4 acc cip len r4;
    let tmp = alloca 0uy 16ul in
    store64_be (sub tmp (size 0) (size 8)) (to_u64 (size_to_uint32 aad_len *. u32 8));
    store64_be (sub tmp (size 8) (size 8)) (to_u64 (size_to_uint32 len *. u32 8));
    poly4 acc tmp (size 16) r4;
    decode tmp acc;
    let h0 = ST.get() in
    loop_nospec #h0 (size 16) tmp
      (fun i -> tmp.(i) <- FStar.UInt8.(tmp.(i) ^^ tag_mix.(i)));
    blit tmp (size 0) out len (size 16);
    pop_frame()