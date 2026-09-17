/*============================================================================
 * UEABS lid-driven cavity, 111M cells: one level of uniform refinement of the
 * 13M-cell base mesh, splitting every cell into 8.
 *
 * This is the one part of the case setup.xml can't express. It's the
 * PRACE UEABS 2.2 cs_user_mesh.c (code_saturne 7.0.0) with tot_nb_mm = 1,
 * and 08-benchmark.sh only adds it to the 111M case.
 *============================================================================*/

#include "cs_headers.h"

void
cs_user_mesh_modify(cs_mesh_t  *mesh)
{
  cs_mesh_refine_simple_selected(mesh,
                                 true,          /* conforming */
                                 mesh->n_cells,
                                 nullptr);      /* every cell */
}

void
cs_user_mesh_save(cs_mesh_t  *mesh)
{
  /* Don't write the 111M-cell mesh back out. */
  mesh->save_if_modified = 0;
}
