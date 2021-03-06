(*
 * Copyright (C) 2012-2013 Citrix Inc
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *)

type buf = (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

type grant_table_index = int32

let grant_table_index_of_int32 x = x
let int32_of_grant_table_index x = x

let grant_table_index_of_string = Int32.of_string
let string_of_grant_table_index = Int32.to_string

module Gnttab = struct
  type interface

  external interface_open: unit -> interface = "stub_xc_gnttab_open"
  external interface_close: interface -> unit = "stub_xc_gnttab_close"

  type grant = {
    domid: int;
    ref: grant_table_index;
  }

  module Local_mapping = struct
    type t = buf
    let to_buf t = t
  end

  external map_exn: interface -> int -> int32 -> int -> Local_mapping.t =
    "stub_xc_gnttab_map_grant_ref"
  external mapv_exn: interface -> int32 array -> int -> Local_mapping.t =
    "stub_xc_gnttab_map_grant_refs"
  external unmap_exn: interface -> Local_mapping.t -> unit =
    "stub_xc_gnttab_unmap"

  (* Look up the values of PROT_{READ,WRITE} from the C headers. *)
  type perm = PROT_NONE | PROT_READ | PROT_WRITE | PROT_RDWR

  external int_of_perm: perm -> int = "stub_xc_gnttab_get_perm"

  let map_exn h g p =
    map_exn h g.domid g.ref
      (int_of_perm (if p then PROT_RDWR else PROT_READ))

  let map h g p = try Some (map_exn h g p) with _ -> None

  let mapv_exn h gs p =
    let count = List.length gs in
    let grant_array = Array.create (count * 2) 0l in
    let (_: int) = List.fold_left (fun i g ->
        grant_array.(i * 2 + 0) <- Int32.of_int g.domid;
        grant_array.(i * 2 + 1) <- g.ref;
        i+1
      ) 0 gs in
    mapv_exn h grant_array (int_of_perm (if p then PROT_RDWR else PROT_READ))

  let mapv h gs p = try Some (mapv_exn h gs p) with _ -> None
end

module Gntshr = struct
	type interface

	external interface_open: unit -> interface = "stub_xc_gntshr_open"
	external interface_close: interface -> unit = "stub_xc_gntshr_close"

	type share = {
		refs: grant_table_index list;
		mapping: buf;
	}

	external share_pages_exn: interface -> int32 -> int -> bool -> share =
		"stub_xc_gntshr_share_pages"
	external munmap_exn: interface -> share -> unit =
		"stub_xc_gntshr_munmap"

	exception Need_xen_4_2_or_later

	let () = Callback.register_exception "gntshr.missing" Need_xen_4_2_or_later

	let share_pages_exn interface domid count writeable =
		let domid32 = Int32.of_int domid in
		share_pages_exn interface domid32 count writeable

	let share_pages interface domid count writeable =
		try Some (share_pages_exn interface domid count writeable)
		with _ -> None
end
