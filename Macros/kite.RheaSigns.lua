script_name        = "Rhea Signs"
script_description = "Typesetting and sign operations suite"
script_author      = "Kiterow"
script_version     = "1.8.5"
script_namespace   = "kite.RheaSigns"

local MAX_MARKER_ID = 9999
local RHEA_ZERO_EPSILON = 1e-9
local RHEA_DIMENSION_EPSILON = 0.0001

local HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
local HOTKEY_MENU_SCRIPT = script_name

include("karaskel.lua")


local DependencyControl = require("l0.DependencyControl")
local depRec = DependencyControl{
    feed        = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        { "l0.ASSFoundation", version = "0.5.0",
          url  = "https://github.com/TypesettingTools/ASSFoundation",
          feed = "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json" },
        { "l0.Functional",   version = "0.6.0",
          url  = "https://github.com/TypesettingTools/Functional",
          feed = "https://raw.githubusercontent.com/TypesettingTools/Functional/master/DependencyControl.json" },
        { "arch.Perspective", version = "1.2.1",
          url  = "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json" },
        { "a-mo.LineCollection", version = "1.3.0",
          url  = "https://github.com/TypesettingTools/Aegisub-Motion",
          feed = "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json" },
        { "a-mo.Line", version = "1.5.3",
          url  = "https://github.com/TypesettingTools/Aegisub-Motion",
          feed = "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json" },
        { "kite.UI", version = "1.1.3",
          url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.LineOps", version = "1.5.2",
          url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.PyBridge", version = "1.4.4",
          url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.EventOps", version = "1.0.3",
          url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.ShapeOptimizer", version = "1.1.0",
          url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
    },
}
local ASS, Functional, ArchPersp, LineCollection, AMLine, KiteUI, LineOps, PyBridge, _, SharedShapeOptimizer = depRec:requireModules()

local function ConfigHandler(interface, file_name, _, version)
    return KiteUI.dialogHandler(interface, script_namespace, version, {
        { path = "?user/" .. file_name, format = "json_sections" },
    })
end

local FunctionalString  = Functional.string
local FunctionalMath    = Functional.math
local FunctionalList    = Functional.list
local FunctionalTable   = Functional.table
local FunctionalUtil    = Functional.util

local unicode = require("aegisub.unicode")


local LANG = {
    en = {
        title_perspectiva = "PERSPECTIVE",
        title_signlayout = "SIGN",
        title_masks = "MASKS",
        title_colorbar = "COLORS",
        title_toolbox = "TOOLBOX",
        lbl_color = "Color:",
        lbl_language = "Language:",
        lbl_action = "Action:",
        lbl_align = "Align:",
        lbl_mode = "Mode:",
        lbl_map = "Map:",
        lbl_org = "Org:",
        lbl_preset = "Preset:",
        lbl_shape = "Shape:",
        lbl_steps = "Steps:",
        lbl_delay = "Delay:",
        lbl_time = "Time:",
        lbl_step = "Step:",
        lbl_amount = "Amount:",
        lbl_quad = "Quad%:",
        lbl_sign = "Sign:",
        lbl_type = "Type:",
        lbl_rot = "Rot:",
        lbl_radius = "Radius:",
        lbl_track = "Track:",
        lbl_vertical_gap = "Y spacing:",
        lbl_mask = "Mask:",
        lbl_source = "Source:",
        lbl_tag = "Tag:",
        lbl_stops = "Stops:",
        btn_execute = "Execute",
        btn_mass_signs = "Signs Editor",
        btn_fastsigns = "FastSigns",
        btn_tagops = "TagOps",
        btn_config = "Config",
        btn_help = "Help",
        btn_save = "Execute",
        btn_cancel = "Cancel",
        btn_continue = "Execute",
        btn_ok = "OK",
        err_no_selection = "No selection.",
        err_tool_load = "Could not load %s:\n\n%s",
        tool_font_manager = "Font and style manager",
        tool_fade_suite = "Fast Fades",
        tool_shuffle_line_text = "Shuffle line text",
        tool_err_shuffle_lines = "Select at least two dialogue lines.",
        tool_undo_shuffle_line_text = "Rhea Signs: shuffle line text",
        lbl_initial = "Initial",
        lbl_final = "Final",
        lbl_kf = "KF",
        lbl_name = "Name",
        lbl_x = "x",
        lbl_y = "y",
        lbl_accel = "Accel",
        lbl_strip = "Strip",
        lbl_char = "Char",
        lbl_layer = "Layer",
        lbl_inv = "Inv",
        lbl_del = "Del",
        lbl_replace = "Replace",
        lbl_alpha = "Alpha",
        lbl_center = "Center",
        lbl_text = "Text",
        lbl_border = "Border",
        lbl_shadow = "Shadow",
        lbl_blur = "Blur",
        lbl_box = "Box",
        lbl_glow = "Glow",
        lbl_fade = "Fade",
        lbl_pad_x = "Pad X",
        lbl_pad_y = "Pad Y",
        lbl_top = "Top",
        lbl_gap = "Gap",
        lbl_max_width = "Max %",
        lbl_box_blur = "Box blur",
        lbl_glow_border = "Glow b",
        lbl_glow_blur = "Glow blur",
        lbl_text_blur = "Text blur",
        tagops_title = "TAG OPS",
        tagops_replace = "Replace matching tags",
        tagops_read_all = "Read all source blocks",
        tagops_append = "Append inside first block",
        tagops_show_result = "Show result",
        tagops_err_copy_select = "Select at least two dialogue lines. Same Effect copies within each group; otherwise the first selected line is the source.",
        tagops_err_select_tag = "Select at least one tag.",
        tagops_err_source_tag = "The source line does not contain any selected tag.",
        tagops_err_adjust_select = "Select at least one line.",
        tagops_err_numeric = "Value must be numeric.",
        tagops_err_no_adjust_tags = "No adjustable numeric tags or style values found.",
        tagops_line = "Line",
        tagops_copied = "Copied",
        tagops_targets = "Targets changed",
        tagops_lines_changed = "Lines changed",
        tagops_tags_changed = "Tags changed",
    },
    es = {
        title_perspectiva = "PERSPECTIVA",
        title_signlayout = "CARTEL",
        title_masks = "MASCARAS",
        title_colorbar = "COLORES",
        title_toolbox = "HERRAMIENTAS",
        lbl_color = "Color:",
        lbl_language = "Idioma:",
        lbl_action = "Accion:",
        lbl_align = "Alinear:",
        lbl_mode = "Modo:",
        lbl_map = "Mapa:",
        lbl_org = "Org:",
        lbl_preset = "Preset:",
        lbl_shape = "Forma:",
        lbl_steps = "Pasos:",
        lbl_delay = "Retardo:",
        lbl_time = "Tiempo:",
        lbl_step = "Paso:",
        lbl_amount = "Cantidad:",
        lbl_quad = "Quad%:",
        lbl_sign = "Cartel:",
        lbl_type = "Tipo:",
        lbl_rot = "Rot:",
        lbl_radius = "Radio:",
        lbl_track = "Track:",
        lbl_vertical_gap = "Espacio Y:",
        lbl_mask = "Mascara:",
        lbl_source = "Fuente:",
        lbl_tag = "Tag:",
        lbl_stops = "Pasos:",
        btn_execute = "Execute",
        btn_mass_signs = "Editor de carteles",
        btn_fastsigns = "FastSigns",
        btn_tagops = "TagOps",
        btn_config = "Config",
        btn_help = "Ayuda",
        btn_save = "Execute",
        btn_cancel = "Cancel",
        btn_continue = "Execute",
        btn_ok = "OK",
        err_no_selection = "Sin seleccion.",
        err_tool_load = "No se pudo cargar %s:\n\n%s",
        tool_font_manager = "Gestor de fuentes y estilos",
        tool_fade_suite = "Fast Fades",
        tool_shuffle_line_text = "Mezclar texto de líneas",
        tool_err_shuffle_lines = "Selecciona al menos dos líneas de diálogo.",
        tool_undo_shuffle_line_text = "Rhea Signs: mezclar texto de líneas",
        lbl_initial = "Inicial",
        lbl_final = "Final",
        lbl_kf = "KF",
        lbl_name = "Nombre",
        lbl_x = "x",
        lbl_y = "y",
        lbl_accel = "Accel",
        lbl_strip = "Quitar",
        lbl_char = "Caracter",
        lbl_layer = "Capa",
        lbl_inv = "Inv",
        lbl_del = "Borrar",
        lbl_replace = "Reemplazar",
        lbl_alpha = "Alfa",
        lbl_center = "Centro",
        lbl_text = "Texto",
        lbl_border = "Borde",
        lbl_shadow = "Sombra",
        lbl_blur = "Blur",
        lbl_box = "Caja",
        lbl_glow = "Brillo",
        lbl_fade = "Fade",
        lbl_pad_x = "Pad X",
        lbl_pad_y = "Pad Y",
        lbl_top = "Arriba",
        lbl_gap = "Espacio",
        lbl_max_width = "Max %",
        lbl_box_blur = "Blur caja",
        lbl_glow_border = "Borde glow",
        lbl_glow_blur = "Blur glow",
        lbl_text_blur = "Blur texto",
        tagops_title = "TAG OPS",
        tagops_replace = "Reemplazar tags iguales",
        tagops_read_all = "Leer todos los bloques",
        tagops_append = "Anexar en primer bloque",
        tagops_show_result = "Mostrar resultado",
        tagops_err_copy_select = "Selecciona al menos dos lineas de dialogo. Mismo Effect copia dentro de cada grupo; si no, la primera seleccionada es la fuente.",
        tagops_err_select_tag = "Selecciona al menos un tag.",
        tagops_err_source_tag = "La linea fuente no contiene ningun tag seleccionado.",
        tagops_err_adjust_select = "Selecciona al menos una linea.",
        tagops_err_numeric = "El valor debe ser numerico.",
        tagops_err_no_adjust_tags = "No se encontraron tags numericos ni valores de estilo ajustables.",
        tagops_line = "Linea",
        tagops_copied = "Copiados",
        tagops_targets = "Destinos cambiados",
        tagops_lines_changed = "Lineas cambiadas",
        tagops_tags_changed = "Tags cambiados",
    },
    pt = {
        title_perspectiva = "PERSPECTIVA",
        title_signlayout = "PLACA",
        title_masks = "MASCARAS",
        title_colorbar = "CORES",
        title_toolbox = "FERRAMENTAS",
        lbl_color = "Cor:",
        lbl_language = "Idioma:",
        lbl_action = "Acao:",
        lbl_align = "Alinhar:",
        lbl_mode = "Modo:",
        lbl_map = "Mapa:",
        lbl_org = "Org:",
        lbl_preset = "Preset:",
        lbl_shape = "Forma:",
        lbl_steps = "Passos:",
        lbl_delay = "Atraso:",
        lbl_time = "Tempo:",
        lbl_step = "Passo:",
        lbl_amount = "Valor:",
        lbl_quad = "Quad%:",
        lbl_sign = "Placa:",
        lbl_type = "Tipo:",
        lbl_rot = "Rot:",
        lbl_radius = "Raio:",
        lbl_track = "Track:",
        lbl_vertical_gap = "Espaço Y:",
        lbl_mask = "Mascara:",
        lbl_source = "Fonte:",
        lbl_tag = "Tag:",
        lbl_stops = "Passos:",
        btn_execute = "Execute",
        btn_mass_signs = "Editor de placas",
        btn_fastsigns = "FastSigns",
        btn_tagops = "TagOps",
        btn_config = "Config",
        btn_help = "Ajuda",
        btn_save = "Execute",
        btn_cancel = "Cancel",
        btn_continue = "Execute",
        btn_ok = "OK",
        err_no_selection = "Sem selecao.",
        err_tool_load = "Nao foi possivel carregar %s:\n\n%s",
        tool_font_manager = "Gerenciador de fontes e estilos",
        tool_fade_suite = "Fast Fades",
        tool_shuffle_line_text = "Embaralhar texto das linhas",
        tool_err_shuffle_lines = "Selecione ao menos duas falas.",
        tool_undo_shuffle_line_text = "Rhea Signs: embaralhar texto das linhas",
        lbl_initial = "Inicial",
        lbl_final = "Final",
        lbl_kf = "KF",
        lbl_name = "Nome",
        lbl_x = "x",
        lbl_y = "y",
        lbl_accel = "Accel",
        lbl_strip = "Remover",
        lbl_char = "Caractere",
        lbl_layer = "Camada",
        lbl_inv = "Inv",
        lbl_del = "Apagar",
        lbl_replace = "Substituir",
        lbl_alpha = "Alfa",
        lbl_center = "Centro",
        lbl_text = "Texto",
        lbl_border = "Borda",
        lbl_shadow = "Sombra",
        lbl_blur = "Blur",
        lbl_box = "Caixa",
        lbl_glow = "Brilho",
        lbl_fade = "Fade",
        lbl_pad_x = "Pad X",
        lbl_pad_y = "Pad Y",
        lbl_top = "Topo",
        lbl_gap = "Espaco",
        lbl_max_width = "Max %",
        lbl_box_blur = "Blur caixa",
        lbl_glow_border = "Borda glow",
        lbl_glow_blur = "Blur glow",
        lbl_text_blur = "Blur texto",
        tagops_title = "TAG OPS",
        tagops_replace = "Substituir tags iguais",
        tagops_read_all = "Ler todos os blocos",
        tagops_append = "Anexar no primeiro bloco",
        tagops_show_result = "Mostrar resultado",
        tagops_err_copy_select = "Selecione ao menos duas linhas de dialogo. Mesmo Effect copia dentro de cada grupo; senao, a primeira selecionada e a fonte.",
        tagops_err_select_tag = "Selecione ao menos um tag.",
        tagops_err_source_tag = "A linha fonte nao contem nenhum tag selecionado.",
        tagops_err_adjust_select = "Selecione ao menos uma linha.",
        tagops_err_numeric = "O valor deve ser numerico.",
        tagops_err_no_adjust_tags = "Nenhum tag numerico ou valor de estilo ajustavel encontrado.",
        tagops_line = "Linha",
        tagops_copied = "Copiados",
        tagops_targets = "Destinos alterados",
        tagops_lines_changed = "Linhas alteradas",
        tagops_tags_changed = "Tags alterados",
    },
}
local EXTRA_LANG = {
    en = {
        lang_en = "English", lang_es = "Spanish", lang_pt = "Portuguese",
        btn_delete = "Delete", btn_apply = "Execute", btn_copy_tags = "Copy Tags", btn_keep_only = "Keep Only",
        op_apply_chain = "Apply chain", op_apply_mask = "Apply mask", op_create_layer = "Create layer",
        op_replace_mask = "Replace mask", op_save_shape = "Save shape", op_delete_shape = "Delete shape", op_clean_dr = "Clean DR",
        op_typewriter = "Typewriter", op_vertical_drop = "Vertical drop", op_circle_text = "Circle text", op_curve_text = "Curve text",
        op_clean_sio = "Clean SiO", choice_frame = "Frame", choice_duration = "Duration", choice_normal = "Normal",
        choice_inverted = "Inverted", choice_vertical = "Vertical", choice_from_clip = "From clip",
        pk_copy_exact = "Copy exact (same plane)", pk_copy_static = "Copy static plane (keep \\pos)", pk_copy_move_plane = "Copy move plane (whole plane)",
        pk_copy_swap = "Copy with corner swap", pk_copy_translate = "Copy translate (keep \\pos)", pk_copy_transport = "Copy transport (\\org -> \\pos)",
        pk_mass_fsc = "Mass FSC (lock quad)", pk_scale_quad = "Scale quad (3D box)",
        pk_bake_extra = "Bake extradata", pk_restore_extra = "Restore extradata",
        pk_identity = "Identity reproject", map_abcd = "ABCD (exact copy)", map_badc = "BADC (horizontal mirror)",
        map_dcba = "DCBA (vertical mirror)", map_cdab = "CDAB (rotate 180)", map_bcda = "BCDA (rotate 90 CW)",
        map_dabc = "DABC (rotate 90 CCW)", map_abdc = "ABDC (swap CD)", map_bacd = "BACD (swap AB)",
        map_ab_cd = "AB source + CD target", map_cd_ab = "CD source + AB target", map_ac_bd = "AC source + BD target",
        map_bd_ac = "BD source + AC target", org_keep = "Keep target org", org_center = "Quad center", org_min_fax = "Minimize fax",
        shape_once = "Once (one-way)", shape_round = "Out and back", shape_yoyo = "Yoyo (N cycles)",
        shape_pulse = "Pulse (ms)", shape_steps = "Steps (N)", shape_custom = "Custom keyframes",
        delay_none = "No delay", delay_ms = "ms from start", delay_frame = "Current frame", delay_percent = "Percent (%)",
        fx_blur_in = "Blur in", fx_blur_out = "Blur out", fx_fade_in = "Fade in", fx_fade_out = "Fade out",
        fx_scale_up = "Scale up", fx_scale_down = "Scale down", fx_pop_in = "Pop in", fx_pop_out = "Pop out",
        fx_color_flash = "Color flash", fx_color_pulse = "Color pulse", fx_to_color = "To color (frame)",
        fx_to_style = "To style (frame)", fx_border_pulse = "Border pulse", fx_glow_pulse = "Glow pulse",
        fx_shake_v = "Shake V", fx_shake_h = "Shake H", fx_shake_xy = "Shake XY", fx_wobble = "Wobble (frz)",
        fx_glitch = "Glitch", fx_dramatic_pulse = "Dramatic pulse", fx_flashback = "Flashback (fad)", fx_split_line = "Split line",
        fx_split_line_fad = "Split line fad", fx_split_title = "Split title",
        tagops_adjust = "Resize / transform",
        tagops_transform = "Transform",
        tagops_copy_no_change = "Copy Tags: no target lines changed.",
        tagops_adjust_no_change = "Resize / transform: no values changed.",
        tagops_keep_only_changed = "Keep Only changed %d line(s).",
        tagops_keep_only_no_change = "Keep Only: no tags were removed.",
        tagops_pos_align = "Pos align", tagops_add = "Add", tagops_percent = "Percent",
        tagops_keep_org = "Keep org (pos only)", tagops_move_org = "Move org",
        tagops_err_align_select = "Select at least two dialogue lines. The first selected line is the source and the second is the reference.",
        tagops_err_source_pos = "The first selected line has no \\pos.",
        tagops_err_reference_pos = "The second selected line has no \\pos.",
        tagops_align_no_delta = "The first and second selected lines have no usable \\pos or \\org delta.",
        tagops_align_done = "Pos Align moved %d lines.",
        msg_layout_mismatch_layout = "LayoutResY (%s) does not match PlayResY (%s).",
        msg_layout_mismatch_play = "PlayResY (%s) does not match the video height (%s).",
        msg_layout_depth_scale = "Perspective will use depth scale %.4f. If the script or video resolution is wrong, the generated plane can appear outside the clip.",
        msg_layout_recommended = "Recommended: resample the script or set LayoutResY/PlayResY to match before applying.",
        msg_continue_anyway = "Continue anyway?",
        msg_need_two_copy_lines = "Select >=2 lines. Same Effect = group; empty Effect = one group; otherwise first line copies to all.",
        msg_no_video = "No video loaded.",
        msg_frame_time_unresolved = "Unable to resolve frame time.",
        msg_line_duration_zero = "Line %d: duration 0",
        msg_frame_unavailable = "Frame unavailable.",
        msg_frame_out_of_range = "Frame %dms out of range (%d-%d).",
        msg_line_frame_out_of_range = "Line %d: frame out of range (%d-%d)",
        msg_style_not_found = "style not found",
        msg_missing_pipe = "missing | marker",
        msg_marker_error = "marker error",
        msg_delete_dr_marked = "Delete %d DR-marked lines?",
        msg_no_dr_marked = "No DR-marked lines found.",
        msg_no_dr_marked_selection = "No DR-marked lines in selection.",
        msg_no_vector_curve = "No vector clip found in selection for curve.",
        msg_no_vector_align = "No vector clip found in selection for align.",
        msg_no_usable_path_align = "Vector clip has no usable path for align.",
        signs_editor_title = "== SIGNS EDITOR ==",
        signs_skip_vec = "Skip vector drawings (\\p1)",
        signs_auto_gbc = "Auto-detect and regenerate GBC gradients",
        signs_use_cap = "Apply character limit",
        signs_no_editable = "No editable lines found in selection.",
        signs_original = "ORIGINAL (read-only)",
        signs_modified = "MODIFIED (edit here)",
        signs_regen_gbc = "Regenerate GBC gradients on modified lines",
        signs_info = "%d unique texts, %d total lines. %d GBC detected.",
        signs_skipped_vectors = " Skipped %d vectors.",
        signs_skipped_over_limit = " Skipped %d over limit.",
        signs_line_mismatch = "Line count mismatch: expected %d, got %d.\nNo changes applied.",
        fade_prompt = "Choose a fade operation:", fade_action_intro = "In", fade_action_outro = "Out",
        fade_action_cleanup = "Clean", fade_cancel = "Cancel", fade_err_selection = "Select at least one dialogue line.",
        fade_err_frame_read = "The current video frame could not be read.", fade_err_no_frame = "There is no active video frame.",
        fade_err_frame_ms = "The current frame could not be converted to milliseconds.", fade_err_frame_inside = "The current frame must be inside every selected line.",
        fade_err_line = "Line %d contains an invalid \\fad tag.", fade_err_cleanup_groups = "Select at least two timing groups.",
        fade_undo_intro = "Rhea Signs: fade in from current frame", fade_undo_outro = "Rhea Signs: fade out from current frame",
        fade_undo_cleanup = "Rhea Signs: continuous fade cleanup",
        title_shapes = "SHAPES", lbl_perimeter = "Perimeter:", lbl_intensity = "Intensity:", lbl_threshold = "Threshold:", lbl_bands = "Bands:",
        sh_action_unify = "Unify positions", sh_action_perimeter = "Place on perimeter", sh_action_optimizer = "Shape color optimizer",
        sh_perimeter_exterior = "Exterior contours only", sh_perimeter_holes = "Exterior contours and holes",
        sh_mode_auto = "Auto", sh_mode_similar = "Similar colors", sh_mode_gradient = "Full gradient",
        sh_intensity_balanced = "Balanced", sh_intensity_fidelity = "Fidelity", sh_intensity_aggressive = "Aggressive",
        sh_show_summary = "Show summary", sh_hint_action = "Choose one shape operation.", sh_hint_perimeter_mode = "Used only when placing units on a perimeter.",
        sh_hint_optimizer_mode = "Color reduction strategy.", sh_hint_intensity = "Preset error tolerance.", sh_hint_threshold = "OKLab threshold; 0 uses the intensity preset.", sh_hint_bands = "Maximum bands for full-gradient mode.",
        sh_apply = "Apply", sh_cancel = "Cancel", sh_no_reduction = "No safe reduction was found with these parameters.", sh_confirm_apply = "Apply direct replacement?",
        sh_undo_unify = "Rhea Signs: unify shape positions", sh_undo_perimeter = "Rhea Signs: place shapes on perimeter", sh_undo_optimizer = "Rhea Signs: shape color optimizer",
        sh_err_open_block = "The leading override block is not closed.", sh_err_initial_tags = "The drawing needs leading tags with \\pos and \\pN.",
        sh_err_static_drawing = "Only one static drawing and an optional final {\\p0} are supported.", sh_err_empty_drawing = "The line contains no drawing data.",
        sh_err_exact_pos = "Each line must have exactly one \\pos(x,y).", sh_err_path_command = "The drawing contains the unsupported command '%s'.",
        sh_err_path_data = "The drawing contains data that could not be parsed.", sh_err_coordinates = "The drawing has an invalid coordinate count.",
        sh_err_drawing_scale = "Drawing mode must be \\p1 or higher.", sh_err_positive_scale = "\\fscx and \\fscy must be greater than zero.",
        sh_err_style = "Line %d: style '%s' was not found.", sh_err_line = "Line %d: %s",
        sh_unify_err_selection = "Select at least two drawing lines.", sh_unify_err_tag = "\\%s is not supported because the compensation would not have one static pivot.",
        sh_unify_err_style_rotation = "The style has rotation; use an unrotated drawing first.", sh_unify_err_replace_pos = "The line's \\pos could not be replaced.",
        sh_perimeter_err_before_command = "Coordinates appear before the first drawing command.", sh_perimeter_err_move_pair = "Each %s command must contain exactly one coordinate pair.",
        sh_perimeter_err_line_start = "An l command appears before the initial m command.", sh_perimeter_err_line_pairs = "The l command requires coordinate pairs.",
        sh_perimeter_err_bezier_start = "A b command appears before the initial m command.", sh_perimeter_err_bezier_groups = "The b command requires groups of six coordinates.",
        sh_perimeter_err_spline = "Spline commands s/p/c must first be converted to lines or b Beziers.", sh_perimeter_err_no_contour = "No valid contour was found.",
        sh_perimeter_err_tag = "\\%s is not supported in input geometry.", sh_perimeter_err_style_rotation = "The style has rotation; use unrotated geometry.",
        sh_perimeter_err_alignment = "An effective \\an1..\\an9 could not be determined.", sh_perimeter_err_extent = "The drawing has no geometric extent.",
        sh_perimeter_err_closed = "The perimeter contour must be closed.", sh_perimeter_err_segments = "The perimeter contour has no segments.",
        sh_perimeter_err_zero_length = "The perimeter contour has zero length.", sh_perimeter_err_base_closed = "The base shape contains no usable closed contour.",
        sh_perimeter_err_visible = "The base shape contains no usable visible perimeter.", sh_perimeter_err_selection = "Select the base shape first, followed by at least one unit.",
        sh_perimeter_err_base_line = "Base line %d: %s", sh_perimeter_err_base_exterior = "Base line %d contains no usable exterior contour.",
        sh_perimeter_err_shared_pos = "All layers in a unit must share exactly the same \\pos.", sh_perimeter_err_no_units = "No units were detected after the base shape.",
        sh_perimeter_err_zero_width = "A unit has zero visible width.", sh_perimeter_err_empty_period = "The period cannot be empty.", sh_perimeter_err_invalid_unit = "The period contains an invalid unit.",
        sh_perimeter_custom = "Custom...", sh_perimeter_unit = "Unit %d", sh_perimeter_period_length = "Period length:", sh_perimeter_period_hint = "Only the first steps selected by the length are used.",
        sh_perimeter_step = "Step %d:", sh_perimeter_err_period_length = "The period length is invalid.", sh_perimeter_err_step = "Step %d does not contain a valid unit.",
        sh_perimeter_err_cycles = "The repetition count for contour %d is invalid.", sh_perimeter_err_tangent = "A tangent could not be calculated for contour %d.",
        sh_perimeter_err_advance = "Contour %d has too many repetitions: the advance between units is no longer positive.", sh_perimeter_err_closure = "Pattern closure does not match contour %d.",
        sh_perimeter_err_replace_pos = "A layer's \\pos could not be replaced.", sh_perimeter_err_rotation = "A layer's rotation could not be inserted.",
        sh_perimeter_err_output_limit = "The output would contain %d lines; the safe limit is %d.", sh_perimeter_err_template = "Template line %d: %s",
        sh_perimeter_detected = "Detected units: %d", sh_perimeter_summary = "Exteriors: %d (%s px) | Holes: %d (%s px)", sh_perimeter_pattern = "Periodic pattern:",
        sh_perimeter_close_hint = "Each contour closes its period independently.", sh_perimeter_order_hint = "Order: units 1, 2, 3... by their first \\pos in the selection.", sh_perimeter_err_pattern = "Choose a valid periodic pattern.",
    },
    es = {
        lang_en = "Ingles", lang_es = "Espanol", lang_pt = "Portugues",
        btn_delete = "Borrar", btn_apply = "Execute", btn_copy_tags = "Copiar tags", btn_keep_only = "Keep Only",
        op_apply_chain = "Aplicar cadena", op_apply_mask = "Aplicar mascara", op_create_layer = "Crear capa",
        op_replace_mask = "Reemplazar mascara", op_save_shape = "Guardar forma", op_delete_shape = "Borrar forma", op_clean_dr = "Limpiar DR",
        op_typewriter = "Maquina de escribir", op_vertical_drop = "Caida vertical", op_circle_text = "Texto circular", op_curve_text = "Texto en curva",
        op_clean_sio = "Limpiar SiO", choice_frame = "Frame", choice_duration = "Duracion", choice_normal = "Normal",
        choice_inverted = "Invertido", choice_vertical = "Vertical", choice_from_clip = "Desde clip",
        pk_copy_exact = "Copiar exacto (mismo plano)", pk_copy_static = "Copiar plano estatico (mantener \\pos)", pk_copy_move_plane = "Copiar plano con \\move",
        pk_copy_swap = "Copiar intercambiando esquinas", pk_copy_translate = "Copiar traslacion (mantener \\pos)", pk_copy_transport = "Transportar copia (\\org -> \\pos)",
        pk_mass_fsc = "FSC masivo (bloquear quad)", pk_scale_quad = "Escalar quad (caja 3D)",
        pk_bake_extra = "Guardar extradata", pk_restore_extra = "Restaurar extradata",
        pk_identity = "Reproyectar identidad", map_abcd = "ABCD (copia exacta)", map_badc = "BADC (espejo horizontal)",
        map_dcba = "DCBA (espejo vertical)", map_cdab = "CDAB (rotar 180)", map_bcda = "BCDA (rotar 90 horario)",
        map_dabc = "DABC (rotar 90 antihorario)", map_abdc = "ABDC (intercambiar CD)", map_bacd = "BACD (intercambiar AB)",
        map_ab_cd = "AB fuente + CD destino", map_cd_ab = "CD fuente + AB destino", map_ac_bd = "AC fuente + BD destino",
        map_bd_ac = "BD fuente + AC destino", org_keep = "Mantener org destino", org_center = "Centro del quad", org_min_fax = "Minimizar fax",
        shape_once = "Una vez (ida)", shape_round = "Ida y vuelta", shape_yoyo = "Yoyo (N ciclos)",
        shape_pulse = "Pulso (ms)", shape_steps = "Pasos (N)", shape_custom = "Keyframes personalizados",
        delay_none = "Sin retardo", delay_ms = "ms desde inicio", delay_frame = "Frame actual", delay_percent = "Porcentaje (%)",
        fx_blur_in = "Blur entrada", fx_blur_out = "Blur salida", fx_fade_in = "Fade entrada", fx_fade_out = "Fade salida",
        fx_scale_up = "Escalar arriba", fx_scale_down = "Escalar abajo", fx_pop_in = "Pop entrada", fx_pop_out = "Pop salida",
        fx_color_flash = "Flash de color", fx_color_pulse = "Pulso de color", fx_to_color = "A color (frame)",
        fx_to_style = "A estilo (frame)", fx_border_pulse = "Pulso de borde", fx_glow_pulse = "Pulso de brillo",
        fx_shake_v = "Sacudir V", fx_shake_h = "Sacudir H", fx_shake_xy = "Sacudir XY", fx_wobble = "Tambaleo (frz)",
        fx_glitch = "Glitch", fx_dramatic_pulse = "Pulso dramatico", fx_flashback = "Flashback (fad)", fx_split_line = "Dividir linea",
        fx_split_line_fad = "Dividir linea con fad", fx_split_title = "Dividir titulo",
        tagops_adjust = "Redimensionar / transformar",
        tagops_transform = "Transformar",
        tagops_copy_no_change = "Copiar tags: no cambio ninguna linea destino.",
        tagops_adjust_no_change = "Redimensionar / transformar: no cambio ningun valor.",
        tagops_keep_only_changed = "Keep Only cambio %d linea(s).",
        tagops_keep_only_no_change = "Keep Only: no se quitaron tags.",
        tagops_pos_align = "Alinear pos", tagops_add = "Sumar", tagops_percent = "Porcentaje",
        tagops_keep_org = "Conservar org (solo pos)", tagops_move_org = "Mover org",
        tagops_err_align_select = "Selecciona al menos dos lineas de dialogo. La primera seleccionada es la fuente y la segunda es la referencia.",
        tagops_err_source_pos = "La primera linea seleccionada no tiene \\pos.",
        tagops_err_reference_pos = "La segunda linea seleccionada no tiene \\pos.",
        tagops_align_no_delta = "La primera y segunda linea seleccionadas no tienen delta usable de \\pos ni de \\org.",
        tagops_align_done = "Pos Align movio %d lineas.",
        msg_layout_mismatch_layout = "LayoutResY (%s) no coincide con PlayResY (%s).",
        msg_layout_mismatch_play = "PlayResY (%s) no coincide con la altura del video (%s).",
        msg_layout_depth_scale = "Perspectiva usara escala de profundidad %.4f. Si la resolucion del script o del video esta mal, el plano generado puede quedar fuera del clip.",
        msg_layout_recommended = "Recomendado: remuestrea el script o ajusta LayoutResY/PlayResY para que coincidan antes de aplicar.",
        msg_continue_anyway = "Continuar de todos modos?",
        msg_need_two_copy_lines = "Selecciona >=2 lineas. Mismo Effect = grupo; Effect vacio = un grupo; si no, la primera copia a todas.",
        msg_no_video = "No hay video cargado.",
        msg_frame_time_unresolved = "No se pudo resolver el tiempo del frame.",
        msg_line_duration_zero = "Linea %d: duracion 0",
        msg_frame_unavailable = "Frame no disponible.",
        msg_frame_out_of_range = "Frame %dms fuera de rango (%d-%d).",
        msg_line_frame_out_of_range = "Linea %d: frame fuera de rango (%d-%d)",
        msg_style_not_found = "estilo no encontrado",
        msg_missing_pipe = "sin marcador |",
        msg_marker_error = "error con marcador",
        msg_delete_dr_marked = "Borrar %d lineas marcadas DR?",
        msg_no_dr_marked = "No se encontraron lineas marcadas DR.",
        msg_no_dr_marked_selection = "No hay lineas marcadas DR en la seleccion.",
        msg_no_vector_curve = "No se encontro clip vectorial en la seleccion para curva.",
        msg_no_vector_align = "No se encontro clip vectorial en la seleccion para alinear.",
        msg_no_usable_path_align = "El clip vectorial no tiene ruta usable para alinear.",
        signs_editor_title = "== EDITOR DE CARTELES ==",
        signs_skip_vec = "Omitir dibujos vectoriales (\\p1)",
        signs_auto_gbc = "Detectar y regenerar gradientes GBC automaticamente",
        signs_use_cap = "Aplicar limite de caracteres",
        signs_no_editable = "No se encontraron lineas editables en la seleccion.",
        signs_original = "ORIGINAL (solo lectura)",
        signs_modified = "MODIFICADO (editar aqui)",
        signs_regen_gbc = "Regenerar gradientes GBC en lineas modificadas",
        signs_info = "%d textos unicos, %d lineas totales. %d GBC detectados.",
        signs_skipped_vectors = " %d vectores omitidos.",
        signs_skipped_over_limit = " %d omitidas por limite.",
        signs_line_mismatch = "Cantidad de lineas incorrecta: se esperaban %d, hay %d.\nNo se aplicaron cambios.",
        fade_prompt = "Elige una operacion de fade:", fade_action_intro = "Entrada", fade_action_outro = "Salida",
        fade_action_cleanup = "Limpiar", fade_cancel = "Cancelar", fade_err_selection = "Selecciona al menos una linea de dialogo.",
        fade_err_frame_read = "No se pudo leer el frame de video actual.", fade_err_no_frame = "No hay un frame de video activo.",
        fade_err_frame_ms = "No se pudo convertir el frame actual a milisegundos.", fade_err_frame_inside = "El frame actual debe estar dentro de todas las lineas seleccionadas.",
        fade_err_line = "La linea %d contiene un tag \\fad invalido.", fade_err_cleanup_groups = "Selecciona al menos dos grupos de tiempos.",
        fade_undo_intro = "Rhea Signs: fade de entrada desde el frame actual", fade_undo_outro = "Rhea Signs: fade de salida desde el frame actual",
        fade_undo_cleanup = "Rhea Signs: limpiar fades continuos",
        title_shapes = "SHAPES", lbl_perimeter = "Perimetro:", lbl_intensity = "Intensidad:", lbl_threshold = "Umbral:", lbl_bands = "Bandas:",
        sh_action_unify = "Unificar posiciones", sh_action_perimeter = "Pegar al perimetro", sh_action_optimizer = "Optimizar color de shapes",
        sh_perimeter_exterior = "Solo contornos exteriores", sh_perimeter_holes = "Contornos exteriores y huecos",
        sh_mode_auto = "Auto", sh_mode_similar = "Colores similares", sh_mode_gradient = "Gradiente completo",
        sh_intensity_balanced = "Equilibrado", sh_intensity_fidelity = "Fidelidad", sh_intensity_aggressive = "Agresivo",
        sh_show_summary = "Mostrar resumen", sh_hint_action = "Elige una operacion de shapes.", sh_hint_perimeter_mode = "Se usa solo al colocar unidades en un perimetro.",
        sh_hint_optimizer_mode = "Estrategia de reduccion de colores.", sh_hint_intensity = "Tolerancia de error predefinida.", sh_hint_threshold = "Umbral OKLab; 0 usa la intensidad.", sh_hint_bands = "Maximo de bandas para gradiente completo.",
        sh_apply = "Aplicar", sh_cancel = "Cancelar", sh_no_reduction = "No se encontro una reduccion segura con estos parametros.", sh_confirm_apply = "Aplicar el reemplazo directo?",
        sh_undo_unify = "Rhea Signs: unificar posiciones de shapes", sh_undo_perimeter = "Rhea Signs: pegar shapes al perimetro", sh_undo_optimizer = "Rhea Signs: optimizar color de shapes",
        sh_err_open_block = "El bloque inicial de tags no esta cerrado.", sh_err_initial_tags = "El dibujo necesita tags iniciales con \\pos y \\pN.",
        sh_err_static_drawing = "Solo se admite un dibujo estatico y un {\\p0} final opcional.", sh_err_empty_drawing = "La linea no contiene datos de dibujo.",
        sh_err_exact_pos = "Cada linea debe tener exactamente un \\pos(x,y).", sh_err_path_command = "El dibujo contiene el comando no compatible '%s'.",
        sh_err_path_data = "El dibujo contiene datos que no se pudieron interpretar.", sh_err_coordinates = "El dibujo tiene una cantidad invalida de coordenadas.",
        sh_err_drawing_scale = "El modo de dibujo debe ser \\p1 o superior.", sh_err_positive_scale = "\\fscx y \\fscy deben ser mayores que cero.",
        sh_err_style = "Linea %d: no se encontro el estilo '%s'.", sh_err_line = "Linea %d: %s",
        sh_unify_err_selection = "Selecciona al menos dos lineas de dibujo.", sh_unify_err_tag = "No se admite \\%s porque la compensacion no tendria un unico pivote estatico.",
        sh_unify_err_style_rotation = "El estilo tiene rotacion; usa primero un dibujo sin rotacion.", sh_unify_err_replace_pos = "No se pudo reemplazar el \\pos de la linea.",
        sh_perimeter_err_before_command = "Hay coordenadas antes del primer comando del dibujo.", sh_perimeter_err_move_pair = "Cada comando %s debe tener exactamente un par de coordenadas.",
        sh_perimeter_err_line_start = "Hay un comando l sin un m inicial.", sh_perimeter_err_line_pairs = "El comando l necesita pares de coordenadas.",
        sh_perimeter_err_bezier_start = "Hay un comando b sin un m inicial.", sh_perimeter_err_bezier_groups = "El comando b necesita grupos de seis coordenadas.",
        sh_perimeter_err_spline = "Los comandos spline s/p/c deben convertirse primero a lineas o Bezier b.", sh_perimeter_err_no_contour = "No se encontro ningun contorno valido.",
        sh_perimeter_err_tag = "No se admite \\%s en la geometria de entrada.", sh_perimeter_err_style_rotation = "El estilo tiene rotacion; usa una geometria sin rotacion.",
        sh_perimeter_err_alignment = "No se pudo determinar un \\an1..\\an9 efectivo.", sh_perimeter_err_extent = "El dibujo no tiene extension geometrica.",
        sh_perimeter_err_closed = "El contorno del perimetro debe estar cerrado.", sh_perimeter_err_segments = "El contorno del perimetro no tiene segmentos.",
        sh_perimeter_err_zero_length = "El contorno del perimetro tiene longitud cero.", sh_perimeter_err_base_closed = "La shape base no contiene un contorno cerrado utilizable.",
        sh_perimeter_err_visible = "La shape base no contiene un perimetro visible utilizable.", sh_perimeter_err_selection = "Selecciona primero la shape base y despues al menos una unidad.",
        sh_perimeter_err_base_line = "Linea base %d: %s", sh_perimeter_err_base_exterior = "Linea base %d: no contiene un contorno exterior utilizable.",
        sh_perimeter_err_shared_pos = "Las capas de una unidad deben compartir exactamente el mismo \\pos.", sh_perimeter_err_no_units = "No se detectaron unidades despues de la shape base.",
        sh_perimeter_err_zero_width = "Una unidad tiene ancho visible cero.", sh_perimeter_err_empty_period = "El periodo no puede estar vacio.", sh_perimeter_err_invalid_unit = "El periodo contiene una unidad invalida.",
        sh_perimeter_custom = "Personalizado...", sh_perimeter_unit = "Unidad %d", sh_perimeter_period_length = "Longitud del periodo:", sh_perimeter_period_hint = "Solo se usan los primeros pasos indicados por la longitud.",
        sh_perimeter_step = "Paso %d:", sh_perimeter_err_period_length = "La longitud del periodo no es valida.", sh_perimeter_err_step = "El paso %d no contiene una unidad valida.",
        sh_perimeter_err_cycles = "La cantidad de repeticiones del contorno %d no es valida.", sh_perimeter_err_tangent = "No se pudo calcular una tangente del contorno %d.",
        sh_perimeter_err_advance = "Demasiadas repeticiones en el contorno %d: el avance entre unidades deja de ser positivo.", sh_perimeter_err_closure = "El cierre del patron no coincide con el contorno %d.",
        sh_perimeter_err_replace_pos = "No se pudo reemplazar el \\pos de una capa.", sh_perimeter_err_rotation = "No se pudo insertar la rotacion de una capa.",
        sh_perimeter_err_output_limit = "La salida tendria %d lineas; el limite seguro es %d.", sh_perimeter_err_template = "Linea plantilla %d: %s",
        sh_perimeter_detected = "Unidades detectadas: %d", sh_perimeter_summary = "Exteriores: %d (%s px) | Huecos: %d (%s px)", sh_perimeter_pattern = "Patron periodico:",
        sh_perimeter_close_hint = "Cada contorno cierra su periodo de forma independiente.", sh_perimeter_order_hint = "Orden: unidades 1, 2, 3... segun su primer \\pos en la seleccion.", sh_perimeter_err_pattern = "Elige un patron periodico valido.",
    },
    pt = {
        lang_en = "Ingles", lang_es = "Espanhol", lang_pt = "Portugues",
        btn_delete = "Apagar", btn_apply = "Execute", btn_copy_tags = "Copiar tags", btn_keep_only = "Keep Only",
        op_apply_chain = "Aplicar cadeia", op_apply_mask = "Aplicar mascara", op_create_layer = "Criar camada",
        op_replace_mask = "Substituir mascara", op_save_shape = "Salvar forma", op_delete_shape = "Apagar forma", op_clean_dr = "Limpar DR",
        op_typewriter = "Maquina de escrever", op_vertical_drop = "Queda vertical", op_circle_text = "Texto circular", op_curve_text = "Texto em curva",
        op_clean_sio = "Limpar SiO", choice_frame = "Frame", choice_duration = "Duracao", choice_normal = "Normal",
        choice_inverted = "Invertido", choice_vertical = "Vertical", choice_from_clip = "Do clip",
        pk_copy_exact = "Copiar exato (mesmo plano)", pk_copy_static = "Copiar plano estatico (manter \\pos)", pk_copy_move_plane = "Copiar plano com \\move",
        pk_copy_swap = "Copiar trocando cantos", pk_copy_translate = "Copiar translacao (manter \\pos)", pk_copy_transport = "Transportar copia (\\org -> \\pos)",
        pk_mass_fsc = "FSC em lote (travar quad)", pk_scale_quad = "Escalar quad (caixa 3D)",
        pk_bake_extra = "Gravar extradata", pk_restore_extra = "Restaurar extradata",
        pk_identity = "Reprojetar identidade", map_abcd = "ABCD (copia exata)", map_badc = "BADC (espelho horizontal)",
        map_dcba = "DCBA (espelho vertical)", map_cdab = "CDAB (rotacionar 180)", map_bcda = "BCDA (rotacionar 90 horario)",
        map_dabc = "DABC (rotacionar 90 anti-horario)", map_abdc = "ABDC (trocar CD)", map_bacd = "BACD (trocar AB)",
        map_ab_cd = "AB fonte + CD destino", map_cd_ab = "CD fonte + AB destino", map_ac_bd = "AC fonte + BD destino",
        map_bd_ac = "BD fonte + AC destino", org_keep = "Manter org destino", org_center = "Centro do quad", org_min_fax = "Minimizar fax",
        shape_once = "Uma vez (ida)", shape_round = "Ida e volta", shape_yoyo = "Yoyo (N ciclos)",
        shape_pulse = "Pulso (ms)", shape_steps = "Passos (N)", shape_custom = "Keyframes personalizados",
        delay_none = "Sem atraso", delay_ms = "ms desde inicio", delay_frame = "Frame atual", delay_percent = "Porcentagem (%)",
        fx_blur_in = "Blur entrada", fx_blur_out = "Blur saida", fx_fade_in = "Fade entrada", fx_fade_out = "Fade saida",
        fx_scale_up = "Escalar acima", fx_scale_down = "Escalar abaixo", fx_pop_in = "Pop entrada", fx_pop_out = "Pop saida",
        fx_color_flash = "Flash de cor", fx_color_pulse = "Pulso de cor", fx_to_color = "Para cor (frame)",
        fx_to_style = "Para estilo (frame)", fx_border_pulse = "Pulso de borda", fx_glow_pulse = "Pulso de brilho",
        fx_shake_v = "Tremer V", fx_shake_h = "Tremer H", fx_shake_xy = "Tremer XY", fx_wobble = "Oscilar (frz)",
        fx_glitch = "Glitch", fx_dramatic_pulse = "Pulso dramatico", fx_flashback = "Flashback (fad)", fx_split_line = "Dividir linha",
        fx_split_line_fad = "Dividir linha com fad", fx_split_title = "Dividir titulo",
        tagops_adjust = "Redimensionar / transformar",
        tagops_transform = "Transformar",
        tagops_copy_no_change = "Copiar tags: nenhuma linha destino foi alterada.",
        tagops_adjust_no_change = "Redimensionar / transformar: nenhum valor foi alterado.",
        tagops_keep_only_changed = "Keep Only alterou %d linha(s).",
        tagops_keep_only_no_change = "Keep Only: nenhuma tag foi removida.",
        tagops_pos_align = "Alinhar pos", tagops_add = "Somar", tagops_percent = "Porcentagem",
        tagops_keep_org = "Manter org (so pos)", tagops_move_org = "Mover org",
        tagops_err_align_select = "Selecione ao menos duas linhas de dialogo. A primeira selecionada e a fonte e a segunda e a referencia.",
        tagops_err_source_pos = "A primeira linha selecionada nao tem \\pos.",
        tagops_err_reference_pos = "A segunda linha selecionada nao tem \\pos.",
        tagops_align_no_delta = "A primeira e segunda linhas selecionadas nao tem delta usavel de \\pos nem de \\org.",
        tagops_align_done = "Pos Align moveu %d linhas.",
        msg_layout_mismatch_layout = "LayoutResY (%s) nao coincide com PlayResY (%s).",
        msg_layout_mismatch_play = "PlayResY (%s) nao coincide com a altura do video (%s).",
        msg_layout_depth_scale = "Perspectiva usara escala de profundidade %.4f. Se a resolucao do script ou do video estiver errada, o plano gerado pode ficar fora do clip.",
        msg_layout_recommended = "Recomendado: reamostre o script ou ajuste LayoutResY/PlayResY para coincidirem antes de aplicar.",
        msg_continue_anyway = "Continuar mesmo assim?",
        msg_need_two_copy_lines = "Selecione >=2 linhas. Mesmo Effect = grupo; Effect vazio = um grupo; senao, a primeira copia para todas.",
        msg_no_video = "Nao ha video carregado.",
        msg_frame_time_unresolved = "Nao foi possivel resolver o tempo do frame.",
        msg_line_duration_zero = "Linha %d: duracao 0",
        msg_frame_unavailable = "Frame indisponivel.",
        msg_frame_out_of_range = "Frame %dms fora do intervalo (%d-%d).",
        msg_line_frame_out_of_range = "Linha %d: frame fora do intervalo (%d-%d)",
        msg_style_not_found = "estilo nao encontrado",
        msg_missing_pipe = "sem marcador |",
        msg_marker_error = "erro com marcador",
        msg_delete_dr_marked = "Apagar %d linhas marcadas DR?",
        msg_no_dr_marked = "Nenhuma linha marcada DR encontrada.",
        msg_no_dr_marked_selection = "Nao ha linhas marcadas DR na selecao.",
        msg_no_vector_curve = "Nenhum clip vetorial encontrado na selecao para curva.",
        msg_no_vector_align = "Nenhum clip vetorial encontrado na selecao para alinhar.",
        msg_no_usable_path_align = "O clip vetorial nao tem caminho usavel para alinhar.",
        signs_editor_title = "== EDITOR DE PLACAS ==",
        signs_skip_vec = "Ignorar desenhos vetoriais (\\p1)",
        signs_auto_gbc = "Detectar e regenerar gradientes GBC automaticamente",
        signs_use_cap = "Aplicar limite de caracteres",
        signs_no_editable = "Nenhuma linha editavel encontrada na selecao.",
        signs_original = "ORIGINAL (somente leitura)",
        signs_modified = "MODIFICADO (editar aqui)",
        signs_regen_gbc = "Regenerar gradientes GBC nas linhas modificadas",
        signs_info = "%d textos unicos, %d linhas totais. %d GBC detectados.",
        signs_skipped_vectors = " %d vetores ignorados.",
        signs_skipped_over_limit = " %d ignoradas por limite.",
        signs_line_mismatch = "Quantidade de linhas incorreta: esperadas %d, recebidas %d.\nNenhuma alteracao aplicada.",
        fade_prompt = "Escolha uma operacao de fade:", fade_action_intro = "Entrada", fade_action_outro = "Saida",
        fade_action_cleanup = "Limpar", fade_cancel = "Cancelar", fade_err_selection = "Selecione ao menos uma linha de dialogo.",
        fade_err_frame_read = "Nao foi possivel ler o frame de video atual.", fade_err_no_frame = "Nao ha um frame de video ativo.",
        fade_err_frame_ms = "Nao foi possivel converter o frame atual em milissegundos.", fade_err_frame_inside = "O frame atual deve estar dentro de todas as linhas selecionadas.",
        fade_err_line = "A linha %d contem uma tag \\fad invalida.", fade_err_cleanup_groups = "Selecione ao menos dois grupos de tempos.",
        fade_undo_intro = "Rhea Signs: fade de entrada desde o frame atual", fade_undo_outro = "Rhea Signs: fade de saida desde o frame atual",
        fade_undo_cleanup = "Rhea Signs: limpar fades continuos",
        title_shapes = "FORMAS", lbl_perimeter = "Perimetro:", lbl_intensity = "Intensidade:", lbl_threshold = "Limiar:", lbl_bands = "Faixas:",
        sh_action_unify = "Unificar posicoes", sh_action_perimeter = "Colocar no perimetro", sh_action_optimizer = "Otimizar cores de formas",
        sh_perimeter_exterior = "Somente contornos exteriores", sh_perimeter_holes = "Contornos exteriores e furos",
        sh_mode_auto = "Auto", sh_mode_similar = "Cores semelhantes", sh_mode_gradient = "Gradiente completo",
        sh_intensity_balanced = "Equilibrado", sh_intensity_fidelity = "Fidelidade", sh_intensity_aggressive = "Agressivo",
        sh_show_summary = "Mostrar resumo", sh_hint_action = "Escolha uma operacao de formas.", sh_hint_perimeter_mode = "Usado somente ao colocar unidades em um perimetro.",
        sh_hint_optimizer_mode = "Estrategia de reducao de cores.", sh_hint_intensity = "Tolerancia de erro predefinida.", sh_hint_threshold = "Limiar OKLab; 0 usa a intensidade.", sh_hint_bands = "Maximo de faixas para gradiente completo.",
        sh_apply = "Aplicar", sh_cancel = "Cancelar", sh_no_reduction = "Nenhuma reducao segura foi encontrada com estes parametros.", sh_confirm_apply = "Aplicar a substituicao direta?",
        sh_undo_unify = "Rhea Signs: unificar posicoes de formas", sh_undo_perimeter = "Rhea Signs: colocar formas no perimetro", sh_undo_optimizer = "Rhea Signs: otimizar cores de formas",
        sh_err_open_block = "O bloco inicial de tags nao esta fechado.", sh_err_initial_tags = "O desenho precisa de tags iniciais com \\pos e \\pN.",
        sh_err_static_drawing = "Somente um desenho estatico e um {\\p0} final opcional sao aceitos.", sh_err_empty_drawing = "A linha nao contem dados de desenho.",
        sh_err_exact_pos = "Cada linha deve ter exatamente um \\pos(x,y).", sh_err_path_command = "O desenho contem o comando incompativel '%s'.",
        sh_err_path_data = "O desenho contem dados que nao puderam ser interpretados.", sh_err_coordinates = "O desenho tem uma quantidade invalida de coordenadas.",
        sh_err_drawing_scale = "O modo de desenho deve ser \\p1 ou superior.", sh_err_positive_scale = "\\fscx e \\fscy devem ser maiores que zero.",
        sh_err_style = "Linha %d: o estilo '%s' nao foi encontrado.", sh_err_line = "Linha %d: %s",
        sh_unify_err_selection = "Selecione ao menos duas linhas de desenho.", sh_unify_err_tag = "\\%s nao e aceito porque a compensacao nao teria um unico pivo estatico.",
        sh_unify_err_style_rotation = "O estilo tem rotacao; use primeiro um desenho sem rotacao.", sh_unify_err_replace_pos = "Nao foi possivel substituir o \\pos da linha.",
        sh_perimeter_err_before_command = "Ha coordenadas antes do primeiro comando do desenho.", sh_perimeter_err_move_pair = "Cada comando %s deve ter exatamente um par de coordenadas.",
        sh_perimeter_err_line_start = "Ha um comando l sem um m inicial.", sh_perimeter_err_line_pairs = "O comando l precisa de pares de coordenadas.",
        sh_perimeter_err_bezier_start = "Ha um comando b sem um m inicial.", sh_perimeter_err_bezier_groups = "O comando b precisa de grupos de seis coordenadas.",
        sh_perimeter_err_spline = "Os comandos spline s/p/c devem ser convertidos primeiro em linhas ou Bezier b.", sh_perimeter_err_no_contour = "Nenhum contorno valido foi encontrado.",
        sh_perimeter_err_tag = "\\%s nao e aceito na geometria de entrada.", sh_perimeter_err_style_rotation = "O estilo tem rotacao; use uma geometria sem rotacao.",
        sh_perimeter_err_alignment = "Nao foi possivel determinar um \\an1..\\an9 efetivo.", sh_perimeter_err_extent = "O desenho nao tem extensao geometrica.",
        sh_perimeter_err_closed = "O contorno do perimetro deve estar fechado.", sh_perimeter_err_segments = "O contorno do perimetro nao tem segmentos.",
        sh_perimeter_err_zero_length = "O contorno do perimetro tem comprimento zero.", sh_perimeter_err_base_closed = "A forma base nao contem um contorno fechado utilizavel.",
        sh_perimeter_err_visible = "A forma base nao contem um perimetro visivel utilizavel.", sh_perimeter_err_selection = "Selecione primeiro a forma base e depois ao menos uma unidade.",
        sh_perimeter_err_base_line = "Linha base %d: %s", sh_perimeter_err_base_exterior = "A linha base %d nao contem um contorno exterior utilizavel.",
        sh_perimeter_err_shared_pos = "As camadas de uma unidade devem compartilhar exatamente o mesmo \\pos.", sh_perimeter_err_no_units = "Nenhuma unidade foi detectada depois da forma base.",
        sh_perimeter_err_zero_width = "Uma unidade tem largura visivel zero.", sh_perimeter_err_empty_period = "O periodo nao pode estar vazio.", sh_perimeter_err_invalid_unit = "O periodo contem uma unidade invalida.",
        sh_perimeter_custom = "Personalizado...", sh_perimeter_unit = "Unidade %d", sh_perimeter_period_length = "Comprimento do periodo:", sh_perimeter_period_hint = "Somente os primeiros passos indicados pelo comprimento sao usados.",
        sh_perimeter_step = "Passo %d:", sh_perimeter_err_period_length = "O comprimento do periodo e invalido.", sh_perimeter_err_step = "O passo %d nao contem uma unidade valida.",
        sh_perimeter_err_cycles = "A quantidade de repeticoes do contorno %d e invalida.", sh_perimeter_err_tangent = "Nao foi possivel calcular uma tangente para o contorno %d.",
        sh_perimeter_err_advance = "O contorno %d tem repeticoes demais: o avanco entre unidades deixa de ser positivo.", sh_perimeter_err_closure = "O fechamento do padrao nao coincide com o contorno %d.",
        sh_perimeter_err_replace_pos = "Nao foi possivel substituir o \\pos de uma camada.", sh_perimeter_err_rotation = "Nao foi possivel inserir a rotacao de uma camada.",
        sh_perimeter_err_output_limit = "A saida teria %d linhas; o limite seguro e %d.", sh_perimeter_err_template = "Linha modelo %d: %s",
        sh_perimeter_detected = "Unidades detectadas: %d", sh_perimeter_summary = "Exteriores: %d (%s px) | Furos: %d (%s px)", sh_perimeter_pattern = "Padrao periodico:",
        sh_perimeter_close_hint = "Cada contorno fecha seu periodo de forma independente.", sh_perimeter_order_hint = "Ordem: unidades 1, 2, 3... conforme o primeiro \\pos na selecao.", sh_perimeter_err_pattern = "Escolha um padrao periodico valido.",
    },
}
for code, tbl in pairs(EXTRA_LANG) do
    LANG[code] = LANG[code] or {}
    for key, value in pairs(tbl) do LANG[code][key] = value end
end
local current_lang = "en"
local function L(key)
    local localValue = (LANG[current_lang] and LANG[current_lang][key]) or LANG.en[key]
    if localValue then return localValue end
    return key
end

local function sectionTitle(key)
    return "== " .. L(key) .. " =="
end


local DEFAULT_CONFIG = {
    language = "en",
    mask_color = "#000000",
    fastsign_box_color = "#151515", fastsign_box_alpha = "80",
    fastsign_text_color = "#FFFFFF", fastsign_glow_color = "#000000",
    fastsign_glow_alpha = "20", fastsign_fade_ms = 250,
    fastsign_margin_h = 24, fastsign_margin_v = 16,
    fastsign_top_offset = 30, fastsign_horz_gap = 35,
    fastsign_max_width = 95, fastsign_box_blur = 1.5,
    fastsign_glow_border = 2.5, fastsign_glow_blur = 3,
    fastsign_text_blur = 0.2,
    tagops_action = "Resize / transform", tagops_amount = 0, tagops_mode = "Add",
    tagops_align_org = "Keep org",
    tagops_replace = true, tagops_all_blocks = false, tagops_append = false, tagops_info = false,
    tagops_pos = false, tagops_move = false, tagops_org = false, tagops_clip = false, tagops_iclip = false,
    tagops_fad = false, tagops_fade = false, tagops_t = false, tagops_r = false, tagops_an = false,
    tagops_a = false, tagops_q = false, tagops_fn = false, tagops_fs = false, tagops_fsp = false,
    tagops_fscx = false, tagops_fscy = false, tagops_frz = false, tagops_frx = false, tagops_fry = false,
    tagops_fax = false, tagops_fay = false, tagops_bord = false, tagops_xbord = false, tagops_ybord = false,
    tagops_shad = false, tagops_xshad = false, tagops_yshad = false, tagops_blur = false, tagops_be = false,
    tagops_b = false, tagops_i = false, tagops_u = false, tagops_s = false, tagops_c = false,
    tagops_2c = false, tagops_3c = false, tagops_4c = false, tagops_alpha = false,
    tagops_1a = false, tagops_2a = false, tagops_3a = false, tagops_4a = false,
    tagops_k = false, tagops_kf = false, tagops_ko = false, tagops_p = false, tagops_pbo = false,
    tagops_fe = false,
}
local CONFIG_HANDLER
local RheaConfig = { defaults = {}, sections = {} }
local config_loaded = false
local current_config = FunctionalTable.union(DEFAULT_CONFIG)

local function loadGlobalConfig()
    if not CONFIG_HANDLER then
        local section = {}
        local function addConfigValue(k, v)
            section[k] = { value = v, config = true, name = k, class = "edit" }
        end
        for k, v in pairs(DEFAULT_CONFIG) do addConfigValue(k, v) end
        if RheaConfig and RheaConfig.defaults and RheaConfig.key then
            for prefix, defaults in pairs(RheaConfig.defaults) do
                for key, value in pairs(defaults or {}) do
                    addConfigValue(RheaConfig.key(prefix, key), value)
                end
            end
        end
        CONFIG_HANDLER = ConfigHandler({ rhea = section }, "rhea_signs_config.json", true, script_version)
    end
    if config_loaded then return true end
    local f = io.open(CONFIG_HANDLER.fileName, "r")
    if f then
        f:close()
    else
        CONFIG_HANDLER:write()
    end
    CONFIG_HANDLER:read()
    current_config = CONFIG_HANDLER.configuration.rhea
    current_lang = current_config.language or "en"
    config_loaded = true
    return true
end

local function saveGlobalConfig()
    if CONFIG_HANDLER then CONFIG_HANDLER:write(); return true end
    return false
end

local function resolveConfig()
    loadGlobalConfig()
end


local function showMsg(msg, buttons, opts, dialogOpts)
    opts = opts or {}
    return aegisub.dialog.display({{
        class = "label", label = tostring(msg),
        x = 0, y = 0, width = opts.width or 25, height = opts.height or 4,
    }}, buttons or {L("btn_ok")}, dialogOpts)
end

local Rhea = {}

Rhea.trim             = FunctionalString.trim
Rhea.escapePattern    = FunctionalString.escLuaExp
Rhea.clamp            = FunctionalUtil.clamp
Rhea.round            = FunctionalMath.round
Rhea.roundTo          = function(n, d) return FunctionalMath.round(tonumber(n) or 0, d or 0) end

function Rhea.cloneLine(l)
    if type(l.copy) == "function" then return l:copy() end
    local d = { class = l.class or "dialogue" }
    for k, v in pairs(l) do
        if type(v) == "table" then
            d[k] = {}; for ki, vi in pairs(v) do d[k][ki] = vi end
        else d[k] = v end
    end
    setmetatable(d, getmetatable(l)); return d
end

function Rhea.stripTags(t) return LineOps.analyzeText(t).plain end
function Rhea.visibleText(t) return LineOps.visibleText(t) end
function Rhea.visibleLines(t)
    local lines = LineOps.visibleLines(t)
    for i, line in ipairs(lines) do lines[i] = line ~= "" and line or " " end
    return #lines > 0 and lines or {" "}
end

function Rhea.isDialogue(l) return type(l) == "table" and (l.class == nil or l.class == "dialogue") end

function Rhea.htmlToAss(html)
    if not html or html == "" then return "&H000000&" end
    html = tostring(html)
    local hex = html:match("&[Hh]([%xA-Fa-f]+)&?")
    if hex then
        if #hex > 6 then hex = hex:sub(-6) end
        while #hex < 6 do hex = "0" .. hex end
        return "&H" .. hex:upper() .. "&"
    end
    local r, g, b = html:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then r, g, b = html:match("^#?(%x%x)(%x%x)(%x%x)%x%x$") end
    if r then return "&H" .. b:upper() .. g:upper() .. r:upper() .. "&" end
    return "&H000000&"
end


function Rhea.styleMap(subs)
    local s = {}
    for i = 1, #subs do
        if subs[i].class == "style" then s[subs[i].name] = subs[i] end
    end
    return s
end
function Rhea.formatNum(n, decimals)
    decimals = decimals or 4
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return "0" end
    if n == math.floor(n) then return string.format("%d", math.floor(n + 0.5)) end
    local s = string.format("%." .. decimals .. "f", n)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    if s == "-0" or s == "" then s = "0" end
    return s
end

function Rhea.firstBlock(text)
    return tostring(text or ""):match("^({[^}]*})") or ""
end
function Rhea.injectFirst(text, payload)
    if not payload or payload == "" then return text end
    local fb = Rhea.firstBlock(text)
    if fb ~= "" then
        return "{" .. payload .. fb:sub(2, -2) .. "}" .. text:sub(#fb + 1)
    end
    return "{" .. payload .. "}" .. text
end
function Rhea.isVectorLine(text)
    return LineOps.hasDrawing(text)
end

function Rhea.tokenize(text)
    local tokens, pos = {}, 1
    text = tostring(text or "")
    local n = #text
    while pos <= n do
        local b = text:sub(pos, pos)
        if b == "{" then
            local close = text:find("}", pos + 1, true)
            if close then
                local content = text:sub(pos, close)
                tokens[#tokens + 1] = { type = "tag", content = content }
                pos = close + 1
            else
                tokens[#tokens + 1] = { type = "char", content = "{" }
                pos = pos + 1
            end
        elseif b == "\\" and pos < n then
            local nx = text:sub(pos + 1, pos + 1)
            if nx == "N" or nx == "n" or nx == "h" then
                tokens[#tokens + 1] = { type = "break", content = "\\" .. nx }
                pos = pos + 2
            else
                tokens[#tokens + 1] = { type = "char", content = b }
                pos = pos + 1
            end
        else
            local ch
            for c in unicode.chars(text:sub(pos)) do ch = c; break end
            if ch and ch ~= "" then
                tokens[#tokens + 1] = { type = "char", content = ch }
                pos = pos + #ch
            else
                tokens[#tokens + 1] = { type = "char", content = b }
                pos = pos + 1
            end
        end
    end
    return tokens
end
function Rhea.tokenizeVisible(text)
    local out = {}
    for _, tk in ipairs(Rhea.tokenize(text)) do
        if tk.type ~= "tag" then out[#out + 1] = { type = tk.type, content = tk.content } end
    end
    return out
end

local RHEA_BREAK_SENTINELS = {
    ["\\N"] = string.char(238, 128, 128),
    ["\\n"] = string.char(238, 128, 129),
    ["\\h"] = string.char(238, 128, 130),
}

local RHEA_BREAK_FROM_SENTINEL = {}
for breakText, sentinel in pairs(RHEA_BREAK_SENTINELS) do
    RHEA_BREAK_FROM_SENTINEL[sentinel] = breakText
end

function Rhea.protectVisibleBreaks(text)
    local out = {}
    for _, tk in ipairs(Rhea.tokenize(text)) do
        out[#out + 1] = tk.type == "break" and RHEA_BREAK_SENTINELS[tk.content] or tk.content
    end
    return table.concat(out)
end

function Rhea.restoreVisibleBreaks(text)
    text = tostring(text or "")
    for sentinel, breakText in pairs(RHEA_BREAK_FROM_SENTINEL) do
        text = text:gsub(Rhea.escapePattern(sentinel), breakText)
    end
    return text
end

function Rhea.readMarker(line, prefix)
    return (line and line.effect or ""):match("%[" .. prefix .. "%-([%w]+)%]")
end

local RheaFoundation = setmetatable({}, { __index = Rhea })

local RHEA_TAG_TO_ASS = {
    pos = "position", move = "move", org = "origin",
    clip = "clip_vect", iclip = "iclip_vect",
    fad = "fade_simple", fade = "fade",
    t = "transform", r = "reset",
    an = "align", a = "align",
    q = "wrapstyle", fn = "fontname",
    fs = "fontsize", fsp = "spacing",
    fscx = "scale_x", fscy = "scale_y",
    frz = "angle", fr = "angle",
    frx = "angle_x", fry = "angle_y",
    fax = "shear_x", fay = "shear_y",
    bord = "outline", xbord = "outline_x", ybord = "outline_y",
    shad = "shadow", xshad = "shadow_x", yshad = "shadow_y",
    blur = "blur", be = "blur_edges",
    b = "bold", i = "italic", u = "underline", s = "strikeout",
    c = "color1", ["1c"] = "color1",
    ["2c"] = "color2", ["3c"] = "color3", ["4c"] = "color4",
    alpha = "alpha",
    ["1a"] = "alpha1", ["2a"] = "alpha2", ["3a"] = "alpha3", ["4a"] = "alpha4",
    k = "karaoke", kf = "karaoke_sweep", K = "karaoke_sweep", ko = "karaoke_outline",
    p = "drawing", pbo = "drawing_offset", fe = "encoding",
}

local RHEA_KNOWN_NAMES = {}
for k in pairs(RHEA_TAG_TO_ASS) do RHEA_KNOWN_NAMES[#RHEA_KNOWN_NAMES + 1] = k end
table.sort(RHEA_KNOWN_NAMES, function(a, b) return #a > #b end)

function RheaFoundation.balancedParenEnd(text, startPos)
    local depth = 0
    for i = startPos, #text do
        local c = text:sub(i, i)
        if c == "(" then depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then return i end
        end
    end
    return #text
end

function RheaFoundation.iterTagBlocks(text)
    local blocks, i = {}, 1
    text = tostring(text or "")
    while true do
        local s = text:find("{", i, true); if not s then break end
        local e = text:find("}", s + 1, true); if not e then break end
        blocks[#blocks + 1] = {
            openPos = s, closePos = e,
            content = text:sub(s + 1, e - 1),
        }
        i = e + 1
    end
    return blocks
end

function RheaFoundation.parseTagBlock(block)
    block = tostring(block or "")
    local tags, i = {}, 1
    while i <= #block do
        if block:sub(i, i) == "\\" then
            local nameStart = i + 1
            local name
            for _, known in ipairs(RHEA_KNOWN_NAMES) do
                if block:sub(nameStart, nameStart + #known - 1) == known then
                    name = known
                    break
                end
            end
            if not name then name = block:sub(nameStart):match("^[1-4]?[A-Za-z]+") or "" end
            if name ~= "" then
                local j = nameStart + #name
                local tokenEnd
                if block:sub(j, j) == "(" then
                    tokenEnd = RheaFoundation.balancedParenEnd(block, j)
                else
                    tokenEnd = j - 1
                    while tokenEnd + 1 <= #block and block:sub(tokenEnd + 1, tokenEnd + 1) ~= "\\" do
                        tokenEnd = tokenEnd + 1
                    end
                end
                tags[#tags + 1] = {
                    name = name,
                    raw = block:sub(i, tokenEnd),
                    value = block:sub(j, tokenEnd),
                    startPos = i,
                    endPos = tokenEnd,
                }
                i = tokenEnd + 1
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return tags
end


function RheaFoundation.namesToASS(rawNames)
    local list, seen = {}, {}
    local function addMapped(mapped)
        if not seen[mapped] then seen[mapped] = true; list[#list + 1] = mapped end
    end
    local function add(n)
        if n == "clip" then
            addMapped("clip_vect")
            addMapped("clip_rect")
        elseif n == "iclip" then
            addMapped("iclip_vect")
            addMapped("iclip_rect")
        else
            addMapped(RHEA_TAG_TO_ASS[n] or n)
        end
    end
    if type(rawNames) == "string" then add(rawNames)
    elseif type(rawNames) == "table" then
        if rawNames[1] ~= nil then
            for _, n in ipairs(rawNames) do add(n) end
        else
            for n, v in pairs(rawNames) do if v then add(n) end end
        end
    end
    return list
end

local ASS_LINE_DEFAULTS = {
    class = "dialogue", comment = false, layer = 0,
    start_time = 0, end_time = 0, style = "Default",
    actor = "", margin_l = 0, margin_r = 0, margin_t = 0,
    effect = "", text = "",
}

function RheaFoundation.toASSLine(textOrLine)
    if type(textOrLine) == "table" and textOrLine.__class then return textOrLine end
    local src = type(textOrLine) == "table" and textOrLine or { text = tostring(textOrLine or "") }
    local line = {}
    for k, v in pairs(ASS_LINE_DEFAULTS) do line[k] = v end
    for k, v in pairs(src) do line[k] = v end
    line.text = tostring(line.text or "")
    return AMLine(line, src.parentCollection, {})
end

function RheaFoundation.parseLine(textOrLine)
    if type(textOrLine) == "table" and textOrLine.class == ASS.LineContents then return textOrLine end
    return ASS:parse(RheaFoundation.toASSLine(textOrLine))
end

function RheaFoundation.tryParseLine(textOrLine)
    local ok, data = pcall(RheaFoundation.parseLine, textOrLine)
    return ok and data or nil
end

function RheaFoundation.removeTags(text, rawNames)
    if not text or text == "" then return text end
    local data = RheaFoundation.tryParseLine(text)
    if not data then return text end
    data:removeTags(RheaFoundation.namesToASS(rawNames))
    return data:getString()
end

function RheaFoundation.insertTags(text, payload, mode)
    if not payload or payload == "" then return text end
    if mode == "append" then
        local fb = Rhea.firstBlock(text)
        if fb ~= "" then
            return fb:sub(1, -2) .. payload .. "}" .. text:sub(#fb + 1)
        end
        return "{" .. payload .. "}" .. text
    end
    return Rhea.injectFirst(text, payload)
end

function RheaFoundation.stripAutoMarkers(text)
    return (tostring(text or ""):gsub("{%*[^}]*}", ""))
end

function RheaFoundation.firstClipTag(textOrLine)
    local ok, eff = pcall(function()
        local data = RheaFoundation.parseLine(textOrLine)
        return data:getEffectiveTags(-1, false, true, false).tags
    end)
    if not ok or not eff then return nil end
    return eff.clip_vect or eff.iclip_vect or eff.clip_rect or eff.iclip_rect
end

function RheaFoundation.clipCommandList(clip)
    if not clip then return {} end
    if clip.commands then return clip.commands end
    local out = {}
    for _, contour in ipairs(clip.contours or {}) do
        for _, cmd in ipairs(contour.commands or contour) do
            out[#out + 1] = cmd
        end
    end
    return out
end

function RheaFoundation.clipPoints(clip)
    if not clip then return nil end
    if clip.topLeft and clip.bottomRight then
        local tl, br = clip.topLeft, clip.bottomRight
        return { { tl.x, tl.y }, { br.x, tl.y }, { br.x, br.y }, { tl.x, br.y } }
    end
    local pts = {}
    local function addPoint(p)
        local x = tonumber(p and (p.x or p[1]))
        local y = tonumber(p and (p.y or p[2]))
        if x and y then pts[#pts + 1] = { x, y } end
    end
    for _, cmd in ipairs(RheaFoundation.clipCommandList(clip)) do
        local usedGetter = false
        if type(cmd.getPoints) == "function" then
            local ok, points = pcall(function() return cmd:getPoints(true) end)
            if ok and type(points) == "table" then
                for _, p in ipairs(points) do addPoint(p) end
                usedGetter = true
            end
        end
        if not usedGetter and cmd.x and cmd.y then addPoint(cmd) end
    end
    return pts
end

function RheaFoundation.clipBBox(clip)
    if not clip then return nil end
    if clip.topLeft and clip.bottomRight then
        local tl, br = clip.topLeft, clip.bottomRight
        return math.min(tl.x, br.x), math.min(tl.y, br.y), math.max(tl.x, br.x), math.max(tl.y, br.y)
    end
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(RheaFoundation.clipPoints(clip) or {}) do
        local x, y = p[1], p[2]
        if x < minx then minx = x end
        if y < miny then miny = y end
        if x > maxx then maxx = x end
        if y > maxy then maxy = y end
    end
    if minx == math.huge then return nil end
    return minx, miny, maxx, maxy
end

function RheaFoundation.anchorPointFromAlign(an, x1, y1, x2, y2)
    an = tonumber(an) or 5
    local h = (an - 1) % 3
    local v = math.floor((an - 1) / 3)
    local x = h == 0 and x1 or (h == 1 and (x1 + x2) / 2 or x2)
    local y = v == 0 and y2 or (v == 1 and (y1 + y2) / 2 or y1)
    return x, y
end

function RheaFoundation.setPositionTag(text, x, y, opts)
    text = tostring(text or "")
    if opts and opts.keepMove and LineOps.hasTag(text, "move", true) then return text end
    local pos = string.format("\\pos(%.3f,%.3f)", tonumber(x) or 0, tonumber(y) or 0)
    local replaced, changed = LineOps.replaceTagCall(text, "pos", pos, true)
    if changed then return replaced end
    return Rhea.injectFirst(text, pos)
end

function RheaFoundation.setAlignTag(text, an)
    text = tostring(text or "")
    local align = string.format("\\an%d", tonumber(an) or 5)
    if text:match("\\an[1-9]") then return (text:gsub("\\an[1-9]", align, 1)) end
    return Rhea.injectFirst(text, align)
end

function RheaFoundation.clipCommands(clip)
    if not clip then return nil end
    if clip.topLeft and clip.bottomRight then
        local tl, br = clip.topLeft, clip.bottomRight
        return {
            { type = "m", pts = { tl.x, tl.y } },
            { type = "l", pts = { br.x, tl.y, br.x, br.y, tl.x, br.y, tl.x, tl.y } },
        }
    end
    local out = {}
    for _, cmd in ipairs(RheaFoundation.clipCommandList(clip)) do
        local t = cmd.__tag and cmd.__tag.name
        if t == "m" or t == "l" or t == "n" then
            out[#out + 1] = { type = t == "n" and "m" or t, pts = { cmd.x, cmd.y } }
        elseif t == "b" then
            out[#out + 1] = { type = "b", pts = {
                cmd.x1 or cmd.p1 and cmd.p1.x, cmd.y1 or cmd.p1 and cmd.p1.y,
                cmd.x2 or cmd.p2 and cmd.p2.x, cmd.y2 or cmd.p2 and cmd.p2.y,
                cmd.x or cmd.p3 and cmd.p3.x, cmd.y or cmd.p3 and cmd.p3.y,
            } }
        end
    end
    return #out > 0 and out or nil
end

function RheaFoundation.lineBoundsSize(line, text, style)
    if not line then return nil end
    local sample = Rhea.cloneLine(line)
    if text ~= nil then sample.text = tostring(text or "") end
    local ok, bw, bh = pcall(function()
        local data = RheaFoundation.parseLine(sample)
        local bounds = data:getLineBounds(true)
        if bounds then return bounds.w, bounds.h end
    end)
    if ok and bw and bh then return bw, bh end
    style = style or line.styleref or line.styleRef
    if style then
        local w, h = RheaFoundation.multilineTextExtents(style, sample.text)
        local outline = tonumber(style.outline) or 0
        return w + outline * 2, h + outline * 2
    end
    return nil
end

function RheaFoundation.textExtents(style, text)
    return aegisub.text_extents(style, tostring(text or ""))
end

function RheaFoundation.multilineTextExtents(style, text)
    local width, height = 0, 0
    for _, line in ipairs(Rhea.visibleLines(text)) do
        local w, h = RheaFoundation.textExtents(style, line)
        width = math.max(width, tonumber(w) or 0)
        height = height + math.max(tonumber(h) or 0, 0)
    end
    return width, height
end

function RheaFoundation.groupByTagState(ass, tagName)
    local groups, group = {}, nil
    ass:callback(function(section, sections, i)
        local isAnchor = (i == 1) or (section.instanceOf and section.instanceOf[ASS.Section.Tag] and #section:getTags(tagName) > 0)
        if isAnchor then
            local state = section:getEffectiveTags(true).tags[tagName]
            if group then group.endTagState = state end
            group = { sections = {}, startTagState = state, firstLineIndex = i }
            groups[#groups + 1] = group
        elseif i == #sections then
            group.endTagState = section:getEffectiveTags(true).tags[tagName]
        end
        if group then group.sections[#group.sections + 1] = section end
    end)
    return groups
end

function RheaFoundation.lerpGroup(sections, startTagState, endTagState)
    if not startTagState or not endTagState then return false end
    local totalCharCount = 0
    for _, section in ipairs(sections) do
        if section.instanceOf and section.instanceOf[ASS.Section.Text] then
            totalCharCount = totalCharCount + section.len
        end
    end
    if totalCharCount == 0 then return false end

    local processedCharCount = 0
    local lerpedSections, l = {}, 1
    for s, section in ipairs(sections) do
        if not (section.instanceOf and section.instanceOf[ASS.Section.Text]) then
            lerpedSections[l] = section
            l = l + 1
        else
            local charCount = section.len
            local previousSection = sections[s - 1]
            local startIdx
            if previousSection and previousSection.instanceOf and previousSection.instanceOf[ASS.Section.Tag] then
                previousSection:removeTags(startTagState.__tag.name)
                previousSection:insertTags(startTagState:lerp(endTagState, processedCharCount / totalCharCount))
                local left, right = section:splitAtChar(2, true)
                lerpedSections[l] = left
                section = right
                l = l + 1
                startIdx = 2
            else
                startIdx = 1
            end
            for i = startIdx, charCount do
                local tag = startTagState:lerp(endTagState, (processedCharCount + i - 1) / totalCharCount)
                lerpedSections[l] = ASS.Section.Tag({ tag })
                local left, right = section:splitAtChar(2, true)
                lerpedSections[l + 1] = left
                section = right
                l = l + 2
            end
            processedCharCount = processedCharCount + charCount
        end
    end
    return lerpedSections
end

function RheaFoundation.visibleFromASS(ass)
    local out = {}
    ass:callback(function(section)
        if section.instanceOf and section.instanceOf[ASS.Section.Text] then
            out[#out + 1] = section.value
        end
    end)
    return table.concat(out)
end

function RheaFoundation.replaceVisibleText(ass, newVisible)
    local sections, sizes, total = {}, {}, 0
    ass:callback(function(section)
        if section.instanceOf and section.instanceOf[ASS.Section.Text] then
            sections[#sections + 1] = section
            local size = #Rhea.tokenizeVisible(section.value)
            sizes[#sizes + 1] = size
            total = total + size
        end
    end)
    if #sections == 0 then return false end
    local elems = Rhea.tokenizeVisible(newVisible)
    local newTotal = #elems
    if total == 0 then
        sections[1].value = newVisible
        for i = 2, #sections do sections[i].value = "" end
        return true
    end
    local used = 0
    for i, section in ipairs(sections) do
        local chunk
        if i == #sections then
            chunk = newTotal - used
        else
            local proportional = Rhea.round(newTotal * (sizes[i] / total))
            local leftAfter = newTotal - used - proportional
            local needForRest = #sections - i
            if leftAfter < needForRest then
                proportional = math.max(0, newTotal - used - needForRest)
            end
            chunk = proportional
        end
        local pieces = {}
        for j = 1, chunk do pieces[j] = elems[used + j].content end
        section.value = table.concat(pieces)
        used = used + chunk
    end
    return true
end

function RheaFoundation.detectGBCTag(text)
    local star = tostring(text or ""):match("{%*([^}]+)}")
    if not star then return nil end
    local raw = star:match("^\\([1-4]?[A-Za-z]+)")
    if not raw then return nil end
    return RHEA_TAG_TO_ASS[raw] or raw
end

function RheaFoundation.lerpLine(ass, tagName)
    local groups = RheaFoundation.groupByTagState(ass, tagName)
    local insertOffset = 0
    local applied = false
    for _, group in ipairs(groups) do
        local lerped = RheaFoundation.lerpGroup(group.sections, group.startTagState, group.endTagState)
        if lerped then
            ass:removeSections(insertOffset + group.firstLineIndex, insertOffset + group.firstLineIndex + #group.sections - 1)
            ass:insertSections(lerped, insertOffset + group.firstLineIndex)
            insertOffset = insertOffset + #lerped - #group.sections
            applied = true
        end
    end
    if applied then ass:cleanTags(4) end
    return applied
end

function RheaConfig.key(prefix, key)
    return tostring(prefix or "rhea") .. "_" .. tostring(key)
end


function RheaConfig.read(prefix, defaults)
    local cfg = {}
    for key, value in pairs(defaults or {}) do
        local globalKey = RheaConfig.key(prefix, key)
        if current_config[globalKey] == nil then current_config[globalKey] = value end
        cfg[key] = current_config[globalKey]
    end
    return cfg
end

function RheaConfig.write(prefix, updates, defaults)
    local cfg = RheaConfig.read(prefix, defaults)
    for key, value in pairs(updates or {}) do
        if not defaults or defaults[key] ~= nil then
            current_config[RheaConfig.key(prefix, key)] = value
            cfg[key] = value
        else
            current_config[RheaConfig.key(prefix, key)] = nil
        end
    end
    saveGlobalConfig()
    return cfg
end

function RheaConfig.section(prefix, defaults)
    local section = {
        read = function() return RheaConfig.read(prefix, defaults) end,
        write = function(updates) return RheaConfig.write(prefix, updates, defaults) end,
        defaults = defaults,
    }
    RheaConfig.defaults[prefix] = defaults
    RheaConfig.sections[prefix] = section
    return section
end

function RheaFoundation.nextMarkerSeq(current, used)
    used = used or {}
    local id = ((tonumber(current) or 0) % MAX_MARKER_ID) + 1
    for _ = 1, MAX_MARKER_ID do
        if not used[id] then
            used[id] = true
            return id, id
        end
        id = (id % MAX_MARKER_ID) + 1
    end
    error("Rhea Signs exhausted all available marker IDs.", 0)
end

function RheaFoundation.stampMarker(line, prefix, seq)
    line.effect = line.effect or ""
    local pat = "%[" .. prefix .. "%-%d+%]"
    local cleaned = FunctionalString.trim(line.effect:gsub(pat, "")):gsub("%s+", " ")
    local tag = string.format("[%s-%03d]", prefix, seq)
    line.effect = cleaned ~= "" and (tag .. " " .. cleaned) or tag
end

function RheaFoundation.markerTools(prefix)
    local seq = 0
    local tools = {}
    function tools.next(used)
        local id
        seq, id = RheaFoundation.nextMarkerSeq(seq, used)
        return id
    end
    function tools.reset()
        seq = 0
    end
    function tools.stamp(line, markerID)
        RheaFoundation.stampMarker(line, prefix, tonumber(markerID) or tools.next())
    end
    function tools.read(line)
        return Rhea.readMarker(line, prefix)
    end
    return tools
end

function RheaFoundation.choose(value, items, defaultValue)
    for _, item in ipairs(items or {}) do
        if value == item then return value end
    end
    return defaultValue or items and items[1]
end

function RheaFoundation.chooseAlias(value, aliases, items, defaultValue)
    local aliased = aliases and aliases[tostring(value or "")] or value
    return RheaFoundation.choose(aliased, items, defaultValue)
end

function RheaFoundation.selectionEffectGroups(subs, sel)
    local groups, order = {}, {}
    for _, i in ipairs(sel or {}) do
        local line = subs[i]
        if Rhea.isDialogue(line) then
            local effect = Rhea.trim(tostring(line.effect or ""))
            local key = "effect:" .. effect
            local group = groups[key]
            if not group then
                group = { key = key, effect = effect, source = i, targets = {}, indices = { i } }
                groups[key] = group
                order[#order + 1] = group
            else
                group.targets[#group.targets + 1] = i
                group.indices[#group.indices + 1] = i
            end
        end
    end
    return order
end

function RheaFoundation.selectionDialogueIndices(subs, sel)
    local indices = {}
    for _, i in ipairs(sel or {}) do
        if Rhea.isDialogue(subs[i]) then indices[#indices + 1] = i end
    end
    return indices
end

function RheaFoundation.currentFrameMs()
    if not aegisub or type(aegisub.project_properties) ~= "function" or type(aegisub.ms_from_frame) ~= "function" then
        return nil, "fade_err_frame_read"
    end
    local okProperties, properties = pcall(aegisub.project_properties)
    if not okProperties then return nil, "fade_err_frame_read" end
    local frame = properties and tonumber(properties.video_position)
    if not frame then return nil, "fade_err_no_frame" end
    local okMilliseconds, milliseconds = pcall(aegisub.ms_from_frame, frame)
    milliseconds = tonumber(milliseconds)
    if not okMilliseconds or not milliseconds or milliseconds ~= milliseconds or math.abs(milliseconds) == math.huge then
        return nil, "fade_err_frame_ms"
    end
    return milliseconds
end

local ShapeCore = assert(SharedShapeOptimizer and SharedShapeOptimizer.geometry)
RheaFoundation.Shapes = ShapeCore
function RheaFoundation.selectionCopyGroups(subs, sel)
    local runGroups, skipped = {}, 0
    for _, group in ipairs(RheaFoundation.selectionEffectGroups(subs, sel)) do
        if #group.targets > 0 then
            runGroups[#runGroups + 1] = group
        else
            skipped = skipped + #group.indices
        end
    end
    if #runGroups == 0 then
        local indices = RheaFoundation.selectionDialogueIndices(subs, sel)
        if #indices >= 2 then
            local targets = {}
            for n = 2, #indices do targets[#targets + 1] = indices[n] end
            runGroups[1] = { key = "selection:first", effect = "", source = indices[1], targets = targets, indices = indices }
            skipped = 0
        end
    end
    return runGroups, skipped
end

function RheaFoundation.selectionAfterDeletedLines(sel, deleted)
    local deletedSet, deletedNums = {}, {}
    for _, item in ipairs(deleted or {}) do
        local n = type(item) == "table" and tonumber(item.number) or tonumber(item)
        if n then
            deletedSet[n] = true
            deletedNums[#deletedNums + 1] = n
        end
    end
    if #deletedNums == 0 then return sel or {} end
    table.sort(deletedNums)
    local out = {}
    for _, rawIndex in ipairs(sel or {}) do
        local index = tonumber(rawIndex)
        if index and not deletedSet[index] then
            local shift = 0
            for _, deletedIndex in ipairs(deletedNums) do
                if deletedIndex < index then shift = shift + 1 else break end
            end
            out[#out + 1] = index - shift
        end
    end
    return out
end

function RheaFoundation.tagValue(tag, defaultValue)
    if type(tag) == "table" then
        local n = tonumber(tag.value)
        if n == nil then n = tonumber(tag.dim_value) end
        if n ~= nil then return n end
    end
    return defaultValue
end

function RheaFoundation.setTagValue(tag, value)
    if type(tag) ~= "table" then return end
    local n = tonumber(value) or 0
    tag.value = n
    tag.dim_value = n
end

function RheaFoundation.syncDimTags(tags)
    if type(tags) ~= "table" then return tags end
    for _, name in ipairs({"align", "scale_x", "scale_y", "angle", "angle_x", "angle_y", "shear_x", "shear_y", "fontsize", "outline_x", "outline_y", "shadow_x", "shadow_y"}) do
        if type(tags[name]) == "table" then RheaFoundation.setTagValue(tags[name], RheaFoundation.tagValue(tags[name], 0)) end
    end
    return tags
end

function RheaFoundation.assNumber(n)
    n = tonumber(n)
    if not n then return "0" end
    return tostring(Rhea.roundTo(n))
end

function RheaFoundation.configNumber(value, defaultValue, minValue, maxValue)
    local n = tonumber(value)
    if n == nil then n = tonumber(defaultValue) or 0 end
    if minValue ~= nil and n < minValue then n = minValue end
    if maxValue ~= nil and n > maxValue then n = maxValue end
    return n
end



function RheaFoundation.sanitizeAlpha(a, defaultAlpha)
    local fallback = tostring(defaultAlpha or "80"):upper():match("^%x%x$") or "80"
    local value = tostring(a or ""):upper()
    return value:match("^%x%x$") or value:match("^&H(%x%x)&$") or value:match("(%x%x)") or fallback
end


function RheaFoundation.atan2(dy, dx)
    dy, dx = tonumber(dy) or 0, tonumber(dx) or 0
    if math.atan2 then return math.atan2(dy, dx) end
    if dx > 0 then return math.atan(dy / dx) end
    if dx < 0 and dy >= 0 then return math.atan(dy / dx) + math.pi end
    if dx < 0 then return math.atan(dy / dx) - math.pi end
    if dy > 0 then return math.pi / 2 end
    if dy < 0 then return -math.pi / 2 end
    return 0
end


function RheaFoundation.bezierPoint(t, p0, p1, p2, p3)
    local u = 1 - t
    local tt = t * t
    local uu = u * u
    local uuu = uu * u
    local ttt = tt * t
    return {
        x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x,
        y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y,
    }
end

function RheaFoundation.bezierDerivative(t, p0, p1, p2, p3)
    local u = 1 - t
    local uu = u * u
    local tt = t * t
    return {
        x = 3 * uu * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * tt * (p3.x - p2.x),
        y = 3 * uu * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * tt * (p3.y - p2.y),
    }
end

function RheaFoundation.samplePath(cmds, segments, atan2fn)
    local pts = {}
    local cur = {x=0, y=0}
    local atan = atan2fn or RheaFoundation.atan2
    segments = math.max(1, tonumber(segments) or 30)
    for _, cmd in ipairs(cmds or {}) do
        if cmd.type == "m" and #cmd.pts >= 2 then
            cur = {x = cmd.pts[1], y = cmd.pts[2]}
            pts[#pts + 1] = {p = cur, dist = 0, angle = 0}
        elseif cmd.type == "l" then
            if #pts == 0 then pts[#pts + 1] = {p = cur, dist = 0, angle = 0} end
            for i=1, #cmd.pts - 1, 2 do
                local nx, ny = cmd.pts[i], cmd.pts[i+1]
                local dx, dy = nx - cur.x, ny - cur.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > 0 then
                    local ang = atan(dy, dx)
                    for j=1, segments do
                        local t = j / segments
                        pts[#pts + 1] = {p = {x=cur.x + dx * t, y=cur.y + dy * t}, dist = dist / segments, angle = ang}
                    end
                end
                cur = {x = nx, y = ny}
            end
        elseif cmd.type == "b" then
            if #pts == 0 then pts[#pts + 1] = {p = cur, dist = 0, angle = 0} end
            for i=1, #cmd.pts - 5, 6 do
                local p1 = {x = cmd.pts[i], y = cmd.pts[i+1]}
                local p2 = {x = cmd.pts[i+2], y = cmd.pts[i+3]}
                local p3 = {x = cmd.pts[i+4], y = cmd.pts[i+5]}
                for j=1, segments do
                    local t = j / segments
                    local pt = RheaFoundation.bezierPoint(t, cur, p1, p2, p3)
                    local dp = RheaFoundation.bezierDerivative(t, cur, p1, p2, p3)
                    local prev = pts[#pts] and pts[#pts].p or cur
                    pts[#pts + 1] = {
                        p = pt,
                        dist = math.sqrt((pt.x - prev.x)^2 + (pt.y - prev.y)^2),
                        angle = atan(dp.y, dp.x),
                    }
                end
                cur = p3
            end
        end
    end
    local totalDist = 0
    for i=2, #pts do
        totalDist = totalDist + pts[i].dist
        pts[i].accDist = totalDist
    end
    if #pts > 0 then pts[1].accDist = 0 end
    return pts, totalDist
end


function RheaFoundation.pointOnPath(sampled, targetDist)
    if #sampled == 0 then return nil end
    if targetDist <= 0 then return sampled[1] end
    if targetDist >= sampled[#sampled].accDist then return sampled[#sampled] end
    for i=2, #sampled do
        if sampled[i].accDist >= targetDist then
            local p1, p2 = sampled[i-1], sampled[i]
            local d = p2.accDist - p1.accDist
            if d == 0 then return p2 end
            local t = (targetDist - p1.accDist) / d
            return {
                p = {
                    x = p1.p.x + (p2.p.x - p1.p.x) * t,
                    y = p1.p.y + (p2.p.y - p1.p.y) * t,
                },
                angle = p1.angle + (p2.angle - p1.angle) * t,
            }
        end
    end
    return sampled[#sampled]
end

function RheaFoundation.applyInlineStyleTags(style, tags)
    local data = RheaFoundation.tryParseLine("{" .. tostring(tags or ""):gsub("[{}]", "") .. "}x")
    if not data then return style end
    local eff = data:getEffectiveTags(-1, false, true, false).tags
    if eff.fontsize then style.fontsize = RheaFoundation.tagValue(eff.fontsize, style.fontsize) end
    if eff.scale_x then style.scale_x = RheaFoundation.tagValue(eff.scale_x, style.scale_x) end
    if eff.scale_y then style.scale_y = RheaFoundation.tagValue(eff.scale_y, style.scale_y) end
    if eff.spacing then style.spacing = RheaFoundation.tagValue(eff.spacing, style.spacing) end
    return style
end

function RheaFoundation.cleanByMarker(subs, sel, scope, prefix, confirmFmt, emptyMsg, undoLabel)
    local pool = {}
    if scope == "all" then
        for i = 1, #subs do pool[#pool + 1] = i end
    else
        for _, i in ipairs(sel or {}) do pool[#pool + 1] = i end
    end
    local lines = LineCollection(subs, pool)
    local toDelete = {}
    lines:runCallback(function(_, line)
        if Rhea.readMarker(line, prefix) then toDelete[#toDelete + 1] = line end
    end)
    if #toDelete == 0 then
        if emptyMsg then showMsg(emptyMsg) end
        return sel, false
    end
    if confirmFmt then
        local delete, cancel = L("btn_delete"), L("btn_cancel")
        local btn = aegisub.dialog.display(
            {{class="label", label=string.format(confirmFmt, #toDelete)}},
            {delete, cancel})
        if btn ~= delete then return sel, false end
    end
    lines:deleteLines(toDelete)
    local label = type(undoLabel) == "function" and undoLabel(#toDelete) or undoLabel
    aegisub.set_undo_point(label or string.format("Rhea Signs: clean %s markers", prefix))
    return RheaFoundation.selectionAfterDeletedLines(sel, toDelete), true, #toDelete
end

local function sortedLineEntries(map)
    local entries = {}
    for line, newLines in pairs(map or {}) do
        if newLines and newLines.class then newLines = { newLines } end
        if type(newLines) == "table" and #newLines > 0 then
            entries[#entries + 1] = { line = line, newLines = newLines }
        end
    end
    table.sort(entries, function(a, b) return a.line.number < b.line.number end)
    return entries
end

function RheaFoundation.replaceCollectedLines(lines, replacements, selectLast)
    local toDelete = {}
    local deletedBefore, insertedBefore = 0, 0
    for _, entry in ipairs(sortedLineEntries(replacements)) do
        local insertAt = entry.line.number - deletedBefore + insertedBefore
        for i, newLine in ipairs(entry.newLines) do
            local selected = selectLast == nil and true or (selectLast and i == #entry.newLines)
            lines:addLine(newLine, function() return true end, selected, insertAt + i - 1)
        end
        toDelete[#toDelete + 1] = entry.line
        deletedBefore = deletedBefore + 1
        insertedBefore = insertedBefore + #entry.newLines
    end
    lines:deleteLines(toDelete, false)
    lines:insertLines()
    local newSel = lines:getSelection()
    return #newSel > 0 and newSel or nil
end

function RheaFoundation.insertCollectedLinesAfter(lines, additions, selectLast)
    lines:replaceLines()
    local insertedBefore = 0
    for _, entry in ipairs(sortedLineEntries(additions)) do
        local insertAt = entry.line.number + insertedBefore + 1
        for i, newLine in ipairs(entry.newLines) do
            local selected = selectLast == nil and true or (selectLast and i == #entry.newLines)
            lines:addLine(newLine, function() return true end, selected, insertAt + i - 1)
        end
        insertedBefore = insertedBefore + #entry.newLines
    end
    lines:insertLines()
    local newSel = lines:getSelection()
    return #newSel > 0 and newSel or nil
end


local RheaOps = {
    Perspective = {},
    Masks = {},
    Sign = {},
    Tools = {},
    TagOps = { U = {} },
}

do
local Quad, transformPoints, tagsFromQuad = ArchPersp.Quad, ArchPersp.transformPoints, ArchPersp.tagsFromQuad
local prepareForPerspective = ArchPersp.prepareForPerspective


local DEFAULTS = {
    mode = "Copy w/ corner swap", map = "ABCD (exact copy)",
    orgm = "3 minimize fax",
    set_sx = false, sx = 100, set_sy = false, sy = 100, qscale = 100,
}

local MODE_ITEMS = {
    "Copy Exact (same plane)",
    "Copy Static Plane (keep \\pos)",
    "Copy Move Plane (whole plane)",
    "Copy w/ corner swap",
    "Mass FSC (lock quad)",
    "Scale Quad (3D Box)",
    "Bake Extradata",
    "Restore Extradata",
    "Identity reproject",
}

local ORG_ITEMS = {"1 keep dst org", "2 quad center", "3 minimize fax"}

local LAYOUT_SCALE = 1
local LAYOUT_SCALE_INFO = { scale = 1 }
local PK_LAYOUT_WARNED = {}

local function compute_layout_scale(meta)
    meta = meta or {}
    local play_y = tonumber(meta.PlayResY or meta.playresy or meta.res_y)
    local layout_y = tonumber(meta.LayoutResY or meta.layoutresy)
    local source = layout_y and "LayoutResY" or "video height"
    if not layout_y and aegisub.video_size then
        local ok, _, video_y = pcall(aegisub.video_size)
        if ok then layout_y = tonumber(video_y) end
    end
    local scale = 1
    if play_y and layout_y and play_y > 0 and layout_y > 0 then
        scale = play_y / layout_y
    end
    LAYOUT_SCALE_INFO = {
        scale = scale,
        play_y = play_y,
        layout_y = layout_y,
        source = source,
    }
    return scale
end

local function perspective_mode_uses_layout_scale(mode)
    return mode == "Scale Quad (3D Box)"
        or mode == "Identity reproject"
        or mode == "Mass FSC (lock quad)"
        or (type(mode) == "string" and mode:match("^Copy") ~= nil)
end

local function layout_warning_key()
    local filename = ""
    if aegisub.file_name then
        local ok, name = pcall(aegisub.file_name)
        if ok then filename = tostring(name or "") end
    end
    local info = LAYOUT_SCALE_INFO or {}
    return table.concat({
        filename,
        tostring(info.play_y or ""),
        tostring(info.layout_y or ""),
        tostring(info.source or ""),
    }, "|")
end

local function confirm_layout_scale()
    local info = LAYOUT_SCALE_INFO or {}
    local scale = tonumber(info.scale) or 1
    if math.abs(scale - 1) < RHEA_DIMENSION_EPSILON then return true end
    local key = layout_warning_key()
    if PK_LAYOUT_WARNED[key] then return true end

    local detail
    if info.source == "LayoutResY" then
        detail = string.format(L("msg_layout_mismatch_layout"),
            tostring(info.layout_y or "?"), tostring(info.play_y or "?"))
    else
        detail = string.format(L("msg_layout_mismatch_play"),
            tostring(info.play_y or "?"), tostring(info.layout_y or "?"))
    end
    local msg = detail
        .. string.format("\n\n" .. L("msg_layout_depth_scale"), scale)
        .. "\n\n" .. L("msg_layout_recommended")
        .. "\n\n" .. L("msg_continue_anyway")

    local continue = L("btn_continue")
    local cancel = L("btn_cancel")
    local pressed = aegisub.dialog.display(
        {{class="label", label=msg, x=0, y=0, width=56, height=8}},
        {cancel, continue},
        {cancel=cancel, close=cancel, ok=continue}
    )
    if pressed ~= continue then return false end
    PK_LAYOUT_WARNED[key] = true
    return true
end

local PK_CONFIG = RheaConfig.section("pk", DEFAULTS)


local function dim_tag(v)
    v = tonumber(v) or 0
    return { value = v, dim_value = v }
end

local function perspective_meta(meta)
    meta = meta or {}
    local out = {}
    for k, v in pairs(meta) do out[k] = v end
    local playX = tonumber(out.PlayResX or out.playresx or out.res_x)
    local playY = tonumber(out.PlayResY or out.playresy or out.res_y)
    if (not playX or playX <= 0 or not playY or playY <= 0) and aegisub.video_size then
        local ok, videoX, videoY = pcall(aegisub.video_size)
        if ok then
            playX = playX and playX > 0 and playX or tonumber(videoX)
            playY = playY and playY > 0 and playY or tonumber(videoY)
        end
    end
    out.PlayResX = playX and playX > 0 and playX or 0
    out.PlayResY = playY and playY > 0 and playY or 0
    if out.LayoutResY == nil then out.LayoutResY = out.layoutresy end
    return out
end

local function perspective_style(style, name)
    local out = {}
    if type(style) == "table" then
        for k, v in pairs(style) do out[k] = v end
    end
    local raw = out.raw
    out.class = out.class or "style"
    out.name = out.name or name or "Default"
    out.fontname = out.fontname or "Arial"
    out.fontsize = tonumber(out.fontsize) or 20
    out.scale_x = tonumber(out.scale_x) or 100
    out.scale_y = tonumber(out.scale_y) or 100
    out.angle = tonumber(out.angle) or 0
    out.spacing = tonumber(out.spacing) or 0
    out.outline = tonumber(out.outline) or 0
    out.shadow = tonumber(out.shadow) or 0
    out.margin_l = tonumber(out.margin_l) or 0
    out.margin_r = tonumber(out.margin_r) or 0
    out.margin_t = tonumber(out.margin_t or out.margin_v) or 0
    out.align = tonumber(out.align) or 5
    out.bold = out.bold or false
    out.italic = out.italic or false
    out.underline = out.underline or false
    out.strikeout = out.strikeout or false
    out.color1 = out.color1 or "&H00FFFFFF"
    out.color2 = out.color2 or "&H00FFFFFF"
    out.color3 = out.color3 or "&H00000000"
    out.color4 = out.color4 or "&H00000000"
    out.raw = raw or table.concat({
        out.name, out.fontname, out.fontsize, out.scale_x, out.scale_y, out.angle,
        out.spacing, out.outline, out.shadow, out.margin_l, out.margin_r, out.margin_t,
        out.align, tostring(out.bold), tostring(out.italic), tostring(out.underline),
        tostring(out.strikeout), out.color1, out.color2, out.color3, out.color4,
    }, "|")
    return out
end

local function perspective_styles(styles, lineStyle, style)
    local out = {}
    if type(styles) == "table" then
        for name, st in pairs(styles) do
            if type(st) == "table" then
                out[name] = perspective_style(st, name)
            end
        end
    end
    local styleName = lineStyle or (type(style) == "table" and style.name) or "Default"
    out[styleName] = perspective_style(type(style) == "table" and style or out[styleName], styleName)
    if not out.Default then out.Default = out[styleName] end
    return out
end

local function line_for_perspective(line, style, meta, styles)
    local copy = {}
    for k, v in pairs(line or {}) do copy[k] = v end
    copy.text = tostring(copy.text or "")
    copy.style = copy.style or (type(style) == "table" and style.name) or "Default"
    local pstyles = perspective_styles(styles, copy.style, style)
    copy.styleRef = pstyles[copy.style] or pstyles.Default
    copy.parentCollection = {
        meta = perspective_meta(meta),
        styles = pstyles,
    }
    return copy
end

local function build_tags(line, style, meta, styles)
    local pmeta = perspective_meta(meta)
    local data = RheaFoundation.parseLine(line_for_perspective(line, style, pmeta, styles))
    local eff  = data:getEffectiveTags(-1, true, true, true).tags
    local pos  = eff.position or {
        x = (tonumber(pmeta.PlayResX) or 0) / 2,
        y = (tonumber(pmeta.PlayResY) or 0) / 2,
    }
    local org  = eff.origin or pos
    return {
        align     = eff.align    or dim_tag(style and style.align or 5),
        scale_x   = eff.scale_x  or dim_tag(style and style.scale_x or 100),
        scale_y   = eff.scale_y  or dim_tag(style and style.scale_y or 100),
        angle     = eff.angle    or dim_tag(style and style.angle or 0),
        angle_x   = eff.angle_x  or dim_tag(0),
        angle_y   = eff.angle_y  or dim_tag(0),
        shear_x   = eff.shear_x  or dim_tag(0),
        shear_y   = eff.shear_y  or dim_tag(0),
        fontsize  = eff.fontsize or dim_tag(style and style.fontsize or 20),
        position  = { x = pos.x, y = pos.y },
        origin    = { x = org.x, y = org.y },
        outline_x = eff.outline_x or eff.outline or dim_tag(style and style.outline or 0),
        outline_y = eff.outline_y or eff.outline or dim_tag(style and style.outline or 0),
        shadow_x  = eff.shadow_x or eff.shadow or dim_tag(style and style.shadow or 0),
        shadow_y  = eff.shadow_y or eff.shadow or dim_tag(style and style.shadow or 0),
    }
end

local function serialize_into(line, t)
    RheaFoundation.syncDimTags(t)
    local stripped = RheaFoundation.removeTags(line.text,
        {"fr","frx","fry","frz","fax","fay","fscx","fscy","pos","org"})
    local s = string.format(
        "\\frx%.4f\\fry%.4f\\frz%.4f\\fax%.6f\\fay%.6f\\fscx%.4f\\fscy%.4f\\org(%.3f,%.3f)\\pos(%.3f,%.3f)",
        RheaFoundation.tagValue(t.angle_x, 0), RheaFoundation.tagValue(t.angle_y, 0), RheaFoundation.tagValue(t.angle, 0),
        RheaFoundation.tagValue(t.shear_x, 0), RheaFoundation.tagValue(t.shear_y, 0),
        RheaFoundation.tagValue(t.scale_x, 100), RheaFoundation.tagValue(t.scale_y, 100),
        t.origin.x, t.origin.y,
        t.position.x, t.position.y
    )
    if stripped:match("^{") then
        line.text = stripped:gsub("^{", "{" .. s, 1)
    else
        line.text = "{" .. s .. "}" .. stripped
    end
    line.text = line.text:gsub("{}", "")
end

local function parse_plane_points(raw)
    if raw == nil then return nil end
    raw = tostring(raw):gsub("#7C", "|"):gsub("^e", "")
    local pts = {}
    for x, y in raw:gmatch("([%+%-]?[%d%.]+[eE%+%-]*)%s*;%s*([%+%-]?[%d%.]+[eE%+%-]*)") do
        x, y = tonumber(x), tonumber(y)
        if x and y then
            pts[#pts + 1] = {x, y}
            if #pts >= 4 then break end
        end
    end
    return #pts == 4 and pts or nil
end

local function parse_baked_plane(text)
    local body = tostring(text or ""):match("{\\_persp%(([^%)]*)%)}")
    if not body then return nil end
    local nums = {}
    for n in body:gmatch("[%+%-]?[%d%.]+[eE%+%-]*") do
        nums[#nums + 1] = tonumber(n)
        if #nums >= 8 then break end
    end
    if #nums < 8 then return nil end
    return {
        {nums[1], nums[2]},
        {nums[3], nums[4]},
        {nums[5], nums[6]},
        {nums[7], nums[8]},
    }
end

local function plane_extra_string(pts)
    if type(pts) ~= "table" or #pts < 4 then return nil end
    return string.format("%.3f;%.3f|%.3f;%.3f|%.3f;%.3f|%.3f;%.3f",
        pts[1][1], pts[1][2], pts[2][1], pts[2][2],
        pts[3][1], pts[3][2], pts[4][1], pts[4][2])
end

local function plane_marker(pts)
    if type(pts) ~= "table" or #pts < 4 then return nil end
    return string.format("{\\_persp(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f)}",
        pts[1][1], pts[1][2], pts[2][1], pts[2][2],
        pts[3][1], pts[3][2], pts[4][1], pts[4][2])
end

local function set_plane_extra(line, quad)
    local plane = plane_extra_string(quad)
    if not plane then return false end
    if type(line.extra) ~= "table" then line.extra = {} end
    line.extra["_aegi_perspective_ambient_plane"] = plane
    return true
end


local function bake_extradata(line)
    if type(line.extra) ~= "table" then return false end
    local pts = parse_plane_points(line.extra["_aegi_perspective_ambient_plane"])
    local comment = plane_marker(pts)
    if comment then
        if line.text:match("^{\\_persp%(") then
            line.text = line.text:gsub("^{\\_persp%([^%)]+%)}", comment, 1)
        else
            line.text = comment .. line.text
        end
        return true
    end
    return false
end

local function restore_extradata(line)
    if not line or not line.text then return false end
    local pts = parse_baked_plane(line.text)
    local plane = plane_extra_string(pts)
    if plane then
        if type(line.extra) ~= "table" then line.extra = {} end
        line.extra["_aegi_perspective_ambient_plane"] = plane
        line.text = line.text:gsub("{\\_persp%([^%)]+%)}", "")
        return true
    end
    return false
end



local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and math.abs(n) < 1e7
end

local function valid_dim(n)
    return finite(n) and n > RHEA_DIMENSION_EPSILON
end

local function valid_quad(q)
    if type(q) ~= "table" then return false end
    local area = 0
    for i = 1, 4 do
        if type(q[i]) ~= "table" or not finite(q[i][1]) or not finite(q[i][2]) then
            return false
        end
        local j = (i % 4) + 1
        if q[j] then area = area + q[i][1] * q[j][2] - q[j][1] * q[i][2] end
    end
    return math.abs(area) > 0.01
end

local function tags_are_finite(tags)
    local scalar_tags = {"scale_x", "scale_y", "angle", "angle_x", "angle_y", "shear_x", "shear_y"}
    for _, name in ipairs(scalar_tags) do
        if not tags[name] or not finite(RheaFoundation.tagValue(tags[name])) then return false end
    end
    return tags.position and tags.origin
        and finite(tags.position.x) and finite(tags.position.y)
        and finite(tags.origin.x) and finite(tags.origin.y)
end

local function apply_tags_from_quad(tags, quad, w, h, orgMode)
    if not valid_quad(quad) or not valid_dim(w) or not valid_dim(h) then
        return false
    end
    RheaFoundation.syncDimTags(tags)
    local ok = pcall(function()
        local Q = Quad{quad[1], quad[2], quad[3], quad[4]}
        tagsFromQuad(tags, Q, w, h, orgMode or 3, LAYOUT_SCALE)
    end)
    if not ok then return false end
    RheaFoundation.syncDimTags(tags)
    return tags_are_finite(tags)
end

local function remove_clip_tag(text)
    return RheaFoundation.removeTags(text, {"clip","iclip"})
end

local function shape_extents_for_perspective(text)
    if not Rhea.isVectorLine(text) then return nil end
    local body = LineOps.analyzeText(text).drawing
    local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
    local found = false
    for sx, sy in body:gmatch("([%+%-]?[%d%.]+[eE%+%-]*)%s+([%+%-]?[%d%.]+[eE%+%-]*)") do
        local x, y = tonumber(sx), tonumber(sy)
        if x and y then
            found = true
            if x < minx then minx = x end
            if x > maxx then maxx = x end
            if y < miny then miny = y end
            if y > maxy then maxy = y end
        end
    end
    if not found then return nil end
    return math.max(maxx - minx, 0.01), math.max(maxy - miny, 0.01)
end

local function measure_style_for_perspective(line, style)
    local s = {}
    for k, v in pairs(style or {}) do s[k] = v end
    local head = tostring(line and line.text or ""):match("^{(.-)}") or ""
    RheaFoundation.applyInlineStyleTags(s, head)
    local fn = head:match("\\fn([^\\}]*)")
    if fn and fn ~= "" then s.fontname = fn end
    local b = head:match("\\b([01])")
    if b then s.bold = (b == "1") end
    local i = head:match("\\i([01])")
    if i then s.italic = (i == "1") end
    return s
end

local function get_extents(line, style, tags)
    local sw, sh = shape_extents_for_perspective(line and line.text)
    if valid_dim(sw) and valid_dim(sh) then return sw, sh end

    local clean = Rhea.visibleText(line and line.text or "")
    if clean == "" or clean:match("^%s*$") then return 100, 100 end

    local measureStyle = measure_style_for_perspective(line, style)
    local ok, w, h = pcall(RheaFoundation.multilineTextExtents, measureStyle, line and line.text or "")
    if not ok or not valid_dim(w) or not valid_dim(h) then return 100, 100 end

    local sx = RheaFoundation.tagValue(tags and tags.scale_x, tonumber(measureStyle.scale_x) or 100)
    local sy = RheaFoundation.tagValue(tags and tags.scale_y, tonumber(measureStyle.scale_y) or 100)
    if valid_dim(sx) then w = w / (sx / 100) end
    if valid_dim(sy) then h = h / (sy / 100) end
    if not valid_dim(w) or not valid_dim(h) then return 100, 100 end
    return math.max(w, 0.01), math.max(h, 0.01)
end

local function prepare_tags_for_perspective(line, style, meta, styles)
    local data = RheaFoundation.parseLine(line_for_perspective(line, style, meta, styles))
    if type(prepareForPerspective) == "function" then
        local ok, tags, w, h = pcall(prepareForPerspective, ASS, data)
        if ok and tags and valid_dim(w) and valid_dim(h) then
            if tostring(line and line.text or ""):find("\\N", 1, true)
                or tostring(line and line.text or ""):find("\\n", 1, true) then
                local mw, mh = get_extents(line, style, tags)
                if valid_dim(mw) and valid_dim(mh) then w, h = mw, mh end
            end
            return tags, w, h
        end
    end
    local tags = build_tags(line, style, meta, styles)
    local w, h = get_extents(line, style, tags)
    return tags, w, h
end

local function build_quad_for(line, style, meta, styles)
    local t, w, h = prepare_tags_for_perspective(line, style, meta, styles)
    RheaFoundation.syncDimTags(t)
    local pts = transformPoints(t, w, h, nil, LAYOUT_SCALE)
    local q = {}
    for i = 1, 4 do q[i] = {pts[i][1], pts[i][2]} end
    return q, t, w, h
end

local function safe_build_quad_for(line, style, meta, styles)
    if not line or not style or not line.text then return nil end
    local ok, q, t, w, h = pcall(build_quad_for, line, style, meta, styles)
    if not ok then return nil end
    if not valid_quad(q) or not valid_dim(w) or not valid_dim(h) then
        return nil
    end
    return q, t, w, h
end

local function get_quad_center(q)
    local cx, cy = 0, 0
    for i=1,4 do cx=cx+q[i][1]; cy=cy+q[i][2] end
    return cx/4, cy/4
end

local function scale_quad(q, scale_pct)
    local cx, cy = get_quad_center(q)
    local f = scale_pct / 100
    local nq = {}
    for i=1,4 do
        nq[i] = {
            cx + (q[i][1] - cx) * f,
            cy + (q[i][2] - cy) * f
        }
    end
    return nq
end

local MAPPINGS = {
    {"ABCD (exact copy)",  {1,2,3,4}},
    {"BADC (h-mirror)",    {2,1,4,3}},
    {"DCBA (v-mirror)",    {4,3,2,1}},
    {"CDAB (rot 180)",     {3,4,1,2}},
    {"BCDA (rot 90 CW)",   {2,3,4,1}},
    {"DABC (rot 90 CCW)",  {4,1,2,3}},
    {"ABDC (swap CD)",     {1,2,4,3}},
    {"BACD (swap AB)",     {2,1,3,4}},
    {"AB src + CD dst",    "AB_src_CD_dst"},
    {"CD src + AB dst",    "CD_src_AB_dst"},
    {"AC src + BD dst",    "AC_src_BD_dst"},
    {"BD src + AC dst",    "BD_src_AC_dst"},
}

local function map_names()
    return FunctionalList.map(MAPPINGS, function(v) return v[1] end)
end

local function find_mapping(name)
    for _, v in ipairs(MAPPINGS) do
        if v[1] == name then return v[2] end
    end
    return {1,2,3,4}
end

local function normalizePerspectiveMode(mode)
    if type(mode) == "string" and mode:find("Copy Exact", 1, true) then
        return "Copy Exact (same plane)"
    end
    if type(mode) == "string" and (mode:find("Copy Static Plane", 1, true) or mode:find("Copy Translate", 1, true)) then
        return "Copy Static Plane (keep \\pos)"
    end
    if type(mode) == "string" and (mode:find("Copy Move Plane", 1, true) or mode:find("Copy Transport", 1, true)) then
        return "Copy Move Plane (whole plane)"
    end
    return mode
end

local function normalizePerspectiveMap(name)
    name = tostring(name or "")
    if name:find("^ABCD") then return "ABCD (exact copy)" end
    if name:find("^BADC") then return "BADC (h-mirror)" end
    if name:find("^DCBA") then return "DCBA (v-mirror)" end
    if name:find("^CDAB") then return "CDAB (rot 180)" end
    if name:find("^BCDA") then return "BCDA (rot 90 CW)" end
    if name:find("^DABC") then return "DABC (rot 90 CCW)" end
    if name:find("^ABDC") then return "ABDC (swap CD)" end
    if name:find("^BACD") then return "BACD (swap AB)" end
    if name:find("^AB src") or name:find("^AB source") then return "AB src + CD dst" end
    if name:find("^CD src") or name:find("^CD source") then return "CD src + AB dst" end
    if name:find("^AC src") or name:find("^AC source") then return "AC src + BD dst" end
    if name:find("^BD src") or name:find("^BD source") then return "BD src + AC dst" end
    return name
end

local function remap_quad(src_q, dst_q, m)
    if type(m) == "string" then
        if m == "AB_src_CD_dst" then return {src_q[1], src_q[2], dst_q[3], dst_q[4]}
        elseif m == "CD_src_AB_dst" then return {dst_q[1], dst_q[2], src_q[3], src_q[4]}
        elseif m == "AC_src_BD_dst" then return {src_q[1], dst_q[2], src_q[3], dst_q[4]}
        elseif m == "BD_src_AC_dst" then return {dst_q[1], src_q[2], dst_q[3], src_q[4]}
        end
    end
    return {src_q[m[1]], src_q[m[2]], src_q[m[3]], src_q[m[4]]}
end

local function copy_tag_value(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, value in pairs(v) do out[k] = value end
    return out
end

local PERSPECTIVE_COPY_TAGS = {"angle", "angle_x", "angle_y", "shear_x", "shear_y", "scale_x", "scale_y"}

local function copy_perspective_state(dst, src)
    for _, key in ipairs(PERSPECTIVE_COPY_TAGS) do
        dst[key] = copy_tag_value(src[key])
    end
end

local function quad_from_tags(tags, w, h)
    if not valid_dim(w) or not valid_dim(h) then return nil end
    RheaFoundation.syncDimTags(tags)
    local ok, pts = pcall(transformPoints, tags, w, h, nil, LAYOUT_SCALE)
    if not ok or type(pts) ~= "table" then return nil end
    local q = {}
    for i = 1, 4 do
        if type(pts[i]) ~= "table" then return nil end
        q[i] = {pts[i][1], pts[i][2]}
    end
    return valid_quad(q) and q or nil
end

local function apply_copied_plane(line, tags, w, h, removeClip)
    if not tags_are_finite(tags) then return false end
    local q = quad_from_tags(tags, w, h)
    if not q then return false end
    serialize_into(line, tags)
    set_plane_extra(line, q)
    if removeClip then line.text = remove_clip_tag(line.text) end
    return true
end

local function apply_quad(line, tags, quad, w, h, orgMode, removeClip)
    if not apply_tags_from_quad(tags, quad, w, h, orgMode) then
        return false
    end
    serialize_into(line, tags)
    set_plane_extra(line, quad)
    if removeClip then line.text = remove_clip_tag(line.text) end
    return true
end

local function apply_quad_locked_scale(line, tags, quad, w, h, target_fscx, target_fscy, removeClip)
    if (target_fscx and not valid_dim(target_fscx)) or (target_fscy and not valid_dim(target_fscy)) then
        return false
    end
    local probe = {}
    for k, v in pairs(tags) do
        if type(v) == "table" then
            probe[k] = {}
            for k2, v2 in pairs(v) do probe[k][k2] = v2 end
        end
    end
    if not apply_tags_from_quad(probe, quad, w, h, 3) then
        return false
    end
    local nat_sx = RheaFoundation.tagValue(probe.scale_x, 100)
    local nat_sy = RheaFoundation.tagValue(probe.scale_y, 100)
    local fake_w, fake_h = w, h
    if target_fscx then fake_w = w * nat_sx / target_fscx end
    if target_fscy then fake_h = h * nat_sy / target_fscy end
    if not apply_tags_from_quad(tags, quad, fake_w, fake_h, 3) then
        return false
    end
    if target_fscx then RheaFoundation.setTagValue(tags.scale_x, target_fscx) end
    if target_fscy then RheaFoundation.setTagValue(tags.scale_y, target_fscy) end
    if not tags_are_finite(tags) then return false end
    serialize_into(line, tags)
    set_plane_extra(line, quad)
    if removeClip then line.text = remove_clip_tag(line.text) end
    return true
end

local function build_styles(subs)
    local meta, styles = karaskel.collect_head(subs, false)
    return meta or {}, styles or {}
end

local function perspective_pick_style(styles, name)
    if type(styles) ~= "table" then return nil end
    local style = styles[name]
    if type(style) ~= "table" then style = styles.Default end
    if type(style) ~= "table" then return nil end
    return style
end

function RheaOps.Perspective.context(subs)
    return build_styles(subs)
end

function RheaOps.Perspective.isPerspectiveLine(line)
    if type(line) ~= "table" then return false end
    if type(line.extra) == "table"
        and parse_plane_points(line.extra["_aegi_perspective_ambient_plane"]) then
        return true
    end
    local text = tostring(line.text or "")
    if parse_baked_plane(text) then return true end
    return text:match("\\frx") ~= nil
        or text:match("\\fry") ~= nil
        or text:match("\\fax") ~= nil
        or text:match("\\fay") ~= nil
end

function RheaOps.Perspective.captureQuad(line, style, meta, styles)
    if not RheaOps.Perspective.isPerspectiveLine(line) then return nil end
    local q = safe_build_quad_for(line, style, meta, styles)
    return q
end

function RheaOps.Perspective.reprojectLineToQuad(line, style, meta, styles, quad, selected)
    if not valid_quad(quad) then return false end
    local tags, w, h = prepare_tags_for_perspective(line, style, meta, styles)
    if not tags or not valid_dim(w) or not valid_dim(h) then return false end
    local target_sx = selected and selected.fscx and RheaFoundation.tagValue(tags.scale_x, 100) or nil
    local target_sy = selected and selected.fscy and RheaFoundation.tagValue(tags.scale_y, 100) or nil
    if target_sx or target_sy then
        return apply_quad_locked_scale(line, tags, quad, w, h, target_sx, target_sy, false)
    end
    return apply_quad(line, tags, quad, w, h, 3, false)
end

local function perspectiveFinish(label, changed, zeroMsg)
    if (tonumber(changed) or 0) <= 0 then
        if zeroMsg and zeroMsg ~= "" then showMsg(zeroMsg) end
        return false
    end
    aegisub.set_undo_point(label)
    return true
end

local function run_copy_mode(subs, sel, styles, res, orgMode, meta)
    local is_exact = res.mode == "Copy Exact (same plane)"
    local is_static = res.mode == "Copy Static Plane (keep \\pos)"
    local is_move_plane = res.mode == "Copy Move Plane (whole plane)"
    if not sel or #sel < 2 then
        showMsg(L("msg_need_two_copy_lines"))
        return false
    end
    local mapping = find_mapping(res.map)
    local removeCopyClip = false
    local pairs_done, groups_done = 0, 0
    local run_groups, skipped = RheaFoundation.selectionCopyGroups(subs, sel)
    if #run_groups == 0 then
        showMsg(L("msg_need_two_copy_lines"))
        return false
    end

    for _, g in ipairs(run_groups) do
            local src_line = subs[g.source]
            local src_style = perspective_pick_style(styles, src_line.style)
            local src_q, src_t = safe_build_quad_for(src_line, src_style, meta, styles)
            if src_q then
                for _, i in ipairs(g.targets) do
                    local line = subs[i]
                    local style = perspective_pick_style(styles, line.style)
                    if style then
                        local dst_q, dst_t, dst_w, dst_h = safe_build_quad_for(line, style, meta, styles)
                        if dst_q then
                            if is_exact then
                                copy_perspective_state(dst_t, src_t)
                                dst_t.position = { x = src_t.position.x, y = src_t.position.y }
                                dst_t.origin = { x = src_t.origin.x, y = src_t.origin.y }
                                if apply_copied_plane(line, dst_t, dst_w, dst_h, removeCopyClip) then
                                    subs[i] = line
                                    pairs_done = pairs_done + 1
                                else
                                    skipped = skipped + 1
                                end
                            elseif is_static then
                                copy_perspective_state(dst_t, src_t)
                                dst_t.origin = { x = src_t.origin.x, y = src_t.origin.y }
                                if apply_copied_plane(line, dst_t, dst_w, dst_h, removeCopyClip) then
                                    subs[i] = line
                                    pairs_done = pairs_done + 1
                                else
                                    skipped = skipped + 1
                                end
                            elseif is_move_plane then
                                copy_perspective_state(dst_t, src_t)
                                local dx = dst_t.position.x - src_t.position.x
                                local dy = dst_t.position.y - src_t.position.y
                                dst_t.position = { x = src_t.position.x + dx, y = src_t.position.y + dy }
                                dst_t.origin = { x = src_t.origin.x + dx, y = src_t.origin.y + dy }
                                if apply_copied_plane(line, dst_t, dst_w, dst_h, removeCopyClip) then
                                    subs[i] = line
                                    pairs_done = pairs_done + 1
                                else
                                    skipped = skipped + 1
                                end
                            else
                                local out_q = remap_quad(src_q, dst_q, mapping)
                                if apply_quad(line, dst_t, out_q, dst_w, dst_h, orgMode, removeCopyClip) then
                                    subs[i] = line
                                    pairs_done = pairs_done + 1
                                else
                                    skipped = skipped + 1
                                end
                            end
                        else
                            skipped = skipped + 1
                        end
                    else
                        skipped = skipped + 1
                    end
                end
                groups_done = groups_done + 1
            else
                skipped = skipped + 1
            end
    end
    local tag = is_exact and "exact" or (is_static and "static-plane" or (is_move_plane and "move-plane" or "copy"))
    return perspectiveFinish(
        string.format("Rhea Signs - Perspective: %s (%d grupos, %d destinos, %d omitidos)",
            tag, groups_done, pairs_done, skipped),
        pairs_done,
        string.format("Perspective Copy: 0 lines changed (%d groups, %d skipped).", groups_done, skipped)
    )
end

local function pk_dispatch(subs, sel, opts)
    if not subs or not sel or #sel == 0 then return end
    local meta, styles = build_styles(subs)
    LAYOUT_SCALE = compute_layout_scale(meta)
    local C = PK_CONFIG.read()
    C = FunctionalTable.union(opts or {}, C, DEFAULTS)
    C.mode = normalizePerspectiveMode(C.mode)
    C.map = normalizePerspectiveMap(C.map)
    C.mode = RheaFoundation.choose(C.mode, MODE_ITEMS, DEFAULTS.mode)
    C.map = RheaFoundation.choose(C.map, map_names(), DEFAULTS.map)
    C.orgm = RheaFoundation.choose(C.orgm, ORG_ITEMS, DEFAULTS.orgm)
    PK_CONFIG.write(C)
    local res = C
    local orgMode = tonumber(res.orgm:sub(1,1)) or 3
    if res.mode ~= "Bake Extradata" and res.mode ~= "Restore Extradata" then
        local resolvedMeta = perspective_meta(meta)
        if resolvedMeta.PlayResX <= 0 or resolvedMeta.PlayResY <= 0 then
            showMsg("Perspective tools need a valid script resolution or loaded video dimensions.")
            return false
        end
        meta = resolvedMeta
    end
    if perspective_mode_uses_layout_scale(res.mode) and not confirm_layout_scale() then
        return
    end

    if res.mode == "Bake Extradata" then
        local done = 0
        for _, i in ipairs(sel) do
            local line = subs[i]
            if bake_extradata(line) then
                subs[i] = line
                done = done + 1
            end
        end
        return perspectiveFinish("Rhea Signs - Perspective Bake Extradata", done,
            "Bake Extradata: 0 lines changed (no perspective ambient plane data).")
    end
    if res.mode == "Restore Extradata" then
        local done = 0
        for _, i in ipairs(sel) do
            local line = subs[i]
            if restore_extradata(line) then
                subs[i] = line
                done = done + 1
            end
        end
        return perspectiveFinish("Rhea Signs - Perspective Restore Extradata", done,
            "Restore Extradata: 0 lines changed (no baked \\_persp marker).")
    end
    if res.mode == "Scale Quad (3D Box)" then
        local changed, skipped = 0, 0
        for _, i in ipairs(sel) do
            local line = subs[i]
            local style = perspective_pick_style(styles, line.style)
            if style then
                local q, t, w, h = safe_build_quad_for(line, style, meta, styles)
                if q then
                    local nq = scale_quad(q, res.qscale)
                    if apply_quad(line, t, nq, w, h, orgMode, false) then
                        subs[i] = line
                        changed = changed + 1
                    else
                        skipped = skipped + 1
                    end
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
        return perspectiveFinish("Rhea Signs - Perspective Scale Quad", changed,
            string.format("Scale Quad: 0 lines changed (%d skipped).", skipped))
    end
    if res.mode == "Identity reproject" then
        local changed, skipped = 0, 0
        for _, i in ipairs(sel) do
            local line = subs[i]
            local style = perspective_pick_style(styles, line.style)
            if style then
                local q, t, w, h = safe_build_quad_for(line, style, meta, styles)
                if q then
                    if apply_quad(line, t, q, w, h, orgMode, false) then
                        subs[i] = line
                        changed = changed + 1
                    else
                        skipped = skipped + 1
                    end
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
        return perspectiveFinish("Rhea Signs - Perspective Identity Reproject", changed,
            string.format("Identity reproject: 0 lines changed (%d skipped).", skipped))
    end
    if res.mode == "Mass FSC (lock quad)" then
        local changed, skipped = 0, 0
        for _, i in ipairs(sel) do
            local line = subs[i]
            local style = perspective_pick_style(styles, line.style)
            if style then
                local q, t, w, h = safe_build_quad_for(line, style, meta, styles)
                if q then
                    local fx = res.set_sx and res.sx or RheaFoundation.tagValue(t.scale_x, 100)
                    local fy = res.set_sy and res.sy or RheaFoundation.tagValue(t.scale_y, 100)
                    if apply_quad_locked_scale(line, t, q, w, h, fx, fy, false) then
                        subs[i] = line
                        changed = changed + 1
                    else
                        skipped = skipped + 1
                    end
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
        return perspectiveFinish("Rhea Signs - Perspective Mass FSC", changed,
            string.format("Mass FSC: 0 lines changed (%d skipped).", skipped))
    end
    if res.mode and res.mode:match("^Copy") then
        return run_copy_mode(subs, sel, styles, res, orgMode, meta)
    end
end

RheaOps.Perspective.run = pk_dispatch
RheaOps.Perspective.loadConfig = function()
    local C = PK_CONFIG.read()
    C = FunctionalTable.union(C, DEFAULTS)
    C.mode = normalizePerspectiveMode(C.mode)
    C.map = normalizePerspectiveMap(C.map)
    C.mode = RheaFoundation.choose(C.mode, MODE_ITEMS, DEFAULTS.mode)
    C.map = RheaFoundation.choose(C.map, map_names(), DEFAULTS.map)
    C.orgm = RheaFoundation.choose(C.orgm, ORG_ITEMS, DEFAULTS.orgm)
    return C
end
RheaOps.Perspective.modes = MODE_ITEMS
RheaOps.Perspective.mapNames = map_names
RheaOps.Perspective.orgModes = ORG_ITEMS
end

do

local MASK_FILE = aegisub.decode_path("?user") .. "/dramaturgy_masks.txt"

local BUILTIN_MASKS = [[mask:square:m -50 -50 l 50 -50 50 50 -50 50:
mask:rounded:m -100 -25 b -100 -92 -92 -100 -25 -100 l 25 -100 b 92 -100 100 -92 100 -25 l 100 25 b 100 92 92 100 25 100 l -25 100 b -92 100 -100 92 -100 25 l -100 -25:
mask:circle:m -100 -100 b -45 -155 45 -155 100 -100 b 155 -45 155 45 100 100 b 46 155 -45 155 -100 100 b -155 45 -155 -45 -100 -100:
mask:triangle:m -120 70 l 120 70 l 0 -140:
]]

local function stampSeqMarker(line, seq)
    line.effect = Rhea.trim((line.effect or ""):gsub("%[DR%-%w+%]", ""))
    RheaFoundation.stampMarker(line, "DR", seq)
end

local function clipCommandsToLocalDrawing(cmds, ox, oy)
    local parts = {}
    local firstX, firstY, lastX, lastY
    for _, cmd in ipairs(cmds or {}) do
        parts[#parts + 1] = cmd.type
        for i = 1, #cmd.pts, 2 do
            local x = (tonumber(cmd.pts[i]) or 0) - ox
            local y = (tonumber(cmd.pts[i + 1]) or 0) - oy
            if not firstX then firstX, firstY = x, y end
            lastX, lastY = x, y
            parts[#parts + 1] = RheaFoundation.assNumber(x)
            parts[#parts + 1] = RheaFoundation.assNumber(y)
        end
    end
    if firstX and lastX and (math.abs(firstX - lastX) > 0.001 or math.abs(firstY - lastY) > 0.001) then
        parts[#parts + 1] = "l"
        parts[#parts + 1] = RheaFoundation.assNumber(firstX)
        parts[#parts + 1] = RheaFoundation.assNumber(firstY)
    end
    return Rhea.trim(table.concat(parts, " "))
end

local function extractClipMaskShape(text)
    local clip = RheaFoundation.firstClipTag(text)
    if not clip then return nil end
    local x1, y1, x2, y2 = RheaFoundation.clipBBox(clip)
    if not x1 or not y1 or not x2 or not y2 then return nil end
    local cmds = RheaFoundation.clipCommands(clip)
    if not cmds or #cmds == 0 then return nil end
    return clipCommandsToLocalDrawing(cmds, x1, y1), x1, y1, x2, y2
end

local function replaceDrawing(lineText, shape)
    local text = tostring(lineText or ""):gsub("\\fsc[xy][^}\\]+", "")
    local replaced
    text, replaced = text:gsub("}m%s+[^{}]*", "\\fscx100\\fscy100}" .. shape, 1)
    if replaced == 0 then text = text:gsub("}[^{}]*$", "\\fscx100\\fscy100}" .. shape, 1) end
    return text
end

local DR_DEFAULTS = {
    mask_source = "from clip", alignment = "an7",
    create_layer = true, replace_mask = false, bicubic = false,
    use_alpha = false, alpha_value = "80",
    use_color = true,  color_value = "#000000",
}

local DR_CONFIG = RheaConfig.section("dr", DR_DEFAULTS)

local function loadMaskLibrary()
    local content = PyBridge.readFile(MASK_FILE) or ""
    local masks, names = {}, {"from clip"}
    local source = BUILTIN_MASKS .. content
    if source:sub(-1) ~= "\n" then source = source .. "\n" end
    for name, shape in source:gmatch("mask:(.-):(.-):\n") do
        names[#names + 1] = name
        masks[#masks + 1] = {name = name, shape = shape}
    end
    return masks, names
end

local function saveMask(name, shapeText)
    name = Rhea.trim(name)
    if name == "" or name:match("[:\r\n]") then return false, "El nombre de la máscara no es válido." end
    local shape = tostring(shapeText or ""):gsub("{[^}]-}", ""):match("m%s+[^{}:\r\n]+")
    if not shape then return false, "La línea seleccionada no contiene un dibujo ASS válido." end
    shape = Rhea.trim(shape)
    local content, readError = PyBridge.readFile(MASK_FILE)
    if not content and PyBridge.fileExists(MASK_FILE) then return false, readError end
    content = content or ""
    if content ~= "" and content:sub(-1) ~= "\n" then content = content .. "\n" end
    return PyBridge.writeFile(MASK_FILE, content .. "mask:" .. name .. ":" .. shape .. ":\n\n")
end

local function deleteMask(name)
    name = Rhea.trim(name)
    if name == "" or name:match("[:\r\n]") then return false, "El nombre de la máscara no es válido." end
    local content, readError = PyBridge.readFile(MASK_FILE)
    if not content then
        if PyBridge.fileExists(MASK_FILE) then return false, readError end
        return true
    end
    local updated = content:gsub("mask:" .. Rhea.escapePattern(name) .. ":.-:\n\n?", "")
    if updated == content then return true end
    return PyBridge.writeFile(MASK_FILE, updated)
end

local function findMaskShape(masks, name)
    for i = #(masks or {}), 1, -1 do
        local m = masks[i]
        if m.name == name then return m.shape end
    end
    return nil
end

local function insertedMaskSelection(sel, additions)
    local entries = {}
    for line in pairs(additions) do entries[#entries + 1] = line.number end
    table.sort(entries)

    local selected = {}
    for _, i in ipairs(sel) do
        local shift = 0
        for _, n in ipairs(entries) do if n < i then shift = shift + 1 end end
        selected[#selected + 1] = i + shift
    end
    for offset, n in ipairs(entries) do
        selected[#selected + 1] = n + offset
    end
    return selected
end

local function applyMask(subs, sel, opts)
    local masks, _ = loadMaskLibrary()
    local lines = LineCollection(subs, sel, function() return true end)
    local lineMeta = lines.meta or {}
    local playResX = tonumber(lineMeta.PlayResX or lineMeta.playresx or lineMeta.res_x)
    local playResY = tonumber(lineMeta.PlayResY or lineMeta.playresy or lineMeta.res_y)
    local additions = {}
    local changed = false
    lines:runCallback(function(_, line, seq)
        local text = line.text or ""
        local sourceText = text
        local colorTag = opts.use_color and ("\\c" .. Rhea.htmlToAss(opts.color_value or "#000000")) or ""
        local alphaTag = opts.use_alpha and ("\\alpha&H" .. RheaFoundation.sanitizeAlpha(opts.alpha_value) .. "&") or ""
        local target = line
        local sourceIsClip = opts.mask_source == "from clip"
        local clipPath, x1, y1, x2, y2
        if sourceIsClip then
            clipPath, x1, y1, x2, y2 = extractClipMaskShape(sourceText)
        end
        local libraryShape
        if not sourceIsClip then
            libraryShape = findMaskShape(masks, opts.mask_source)
            if not libraryShape then return end
        end
        if opts.create_layer and not opts.replace_mask then
            if sourceIsClip then
                if not clipPath then return end
            end
            local baseLayer = tonumber(line.layer) or 0
            local mask_line = Rhea.cloneLine(line)
            if baseLayer <= 0 then
                line.layer = 1
                mask_line.layer = 0
                changed = true
            else
                mask_line.layer = baseLayer - 1
            end
            if sourceIsClip then
                mask_line.text = RheaFoundation.removeTags(mask_line.text or "", {"clip", "iclip"})
                line.text = RheaFoundation.removeTags(line.text or "", {"clip", "iclip"})
            end
            additions[line] = mask_line
            changed = true
            target = mask_line
            text = sourceText
        end
        if opts.replace_mask then
            if not text:match("\\p1") then return end
            if sourceIsClip then
                if not clipPath then return end
                local an = tonumber(tostring(opts.alignment or "an7"):match("an([1-9])")) or 7
                local cx, cy = RheaFoundation.anchorPointFromAlign(an, x1, y1, x2, y2)
                target.text = RheaFoundation.removeTags(target.text, {"clip", "iclip"})
                target.text = replaceDrawing(target.text, clipPath)
                target.text = RheaFoundation.setAlignTag(target.text, an)
                target.text = RheaFoundation.setPositionTag(target.text, cx, cy)
            else
                target.text = replaceDrawing(target.text, libraryShape)
            end
            stampSeqMarker(target, seq)
            changed = true
        elseif sourceIsClip then
            if not clipPath then return end
            local an = tonumber(tostring(opts.alignment or "an7"):match("an([1-9])")) or 7
            local cx, cy = RheaFoundation.anchorPointFromAlign(an, x1, y1, x2, y2)
            target.text = string.format(
                "{\\an%d\\blur1\\bord0\\shad0\\fscx100\\fscy100%s%s\\pos(%.3f,%.3f)\\p1}%s",
                an, colorTag, alphaTag, cx, cy, clipPath)
            stampSeqMarker(target, seq)
            changed = true
        else
            local rotTags = ""
            for _, pat in ipairs({"\\org%b()", "\\frz[%d%.%-]+", "\\frx[%d%.%-]+", "\\fry[%d%.%-]+"}) do
                local m = text:match(pat); if m then rotTags = rotTags .. m end
            end
            local posCall = LineOps.lastTagCall(text, "pos", true)
            local posTag = posCall and posCall.raw or ""
            target.text = string.format(
                "{\\%s\\bord0\\shad0\\blur1%s%s%s%s\\p1}%s",
                opts.alignment, rotTags, posTag, colorTag, alphaTag, libraryShape)
            if not LineOps.hasTag(target.text, "pos", true) and playResX and playResY then
                local centerTag = string.format("\\pos(%.3f,%.3f)\\p1", playResX / 2, playResY / 2)
                target.text = target.text:gsub("\\p1", centerTag, 1)
            end
            stampSeqMarker(target, seq)
            changed = true
        end
        if opts.bicubic then
            if target.text:match("\\q2") then
                target.text = target.text:gsub("\\q2", ""):gsub("{}", "")
            else
                target.text = "{\\q2}" .. target.text
                target.text = target.text:gsub("\\q2}{\\", "\\q2\\")
            end
            changed = true
        end
    end)
    if not changed then return sel, false end
    if opts.create_layer and not opts.replace_mask then
        RheaFoundation.insertCollectedLinesAfter(lines, additions, true)
        return insertedMaskSelection(sel, additions), true
    end
    lines:replaceLines()
    return sel, true
end

local function cleanAllDLines(subs, sel)
    return RheaFoundation.cleanByMarker(subs, sel, "all", "DR", L("msg_delete_dr_marked"), L("msg_no_dr_marked"))
end

local function cleanSelectedDLines(subs, sel)
    return RheaFoundation.cleanByMarker(subs, sel, "sel", "DR", nil, L("msg_no_dr_marked_selection"))
end

local function dr_dispatch(subs, sel, opts)
    if not sel or #sel == 0 then showMsg(L("err_no_selection")); return nil, false end
    local cfg = DR_CONFIG.read()
    cfg = FunctionalTable.union(opts or {}, cfg, DR_DEFAULTS)
    if cfg.op == "clean" then return cleanAllDLines(subs, sel) end
    local saved, saveErr = pcall(DR_CONFIG.write, cfg)
    if not saved and aegisub and aegisub.log then
        aegisub.log(1, "Rhea Signs: could not save mask settings: %s\n", tostring(saveErr))
    end
    local newSel, changed = applyMask(subs, sel, cfg)
    if changed then aegisub.set_undo_point("Rhea Signs - Masks Apply") end
    return newSel, changed == true
end
RheaOps.Masks.run = dr_dispatch
RheaOps.Masks.maskNames = function() local _, names = loadMaskLibrary(); return names end
RheaOps.Masks.defaults = DR_DEFAULTS
RheaOps.Masks.loadConfig = DR_CONFIG.read
RheaOps.Masks.saveConfig = DR_CONFIG.write
RheaOps.Masks.saveMask = saveMask
RheaOps.Masks.deleteMask = deleteMask
RheaOps.Masks.cleanAll = cleanAllDLines
RheaOps.Masks.cleanSelected = cleanSelectedDLines

end

do
local sioMarkers = RheaFoundation.markerTools("SiO")
local generateMarkerID = sioMarkers.next
local _so_reset = sioMarkers.reset
local stampEffect = sioMarkers.stamp

local function usedSignMarkerIDs(subs)
    local used = {}
    for i = 1, #subs do
        local id = tonumber(Rhea.readMarker(subs[i], "SiO"))
        if id then used[id] = true end
    end
    return used
end

local SIGN_GEOM_TAGS = {"clip","iclip","pos","move","org","an","frx","fry","frz","fr","fax","fay"}
local function stripGeneratedGeometry(tags)
    return RheaFoundation.removeTags(tostring(tags or ""), SIGN_GEOM_TAGS)
end

local function tagsWithGeometry(tags, geom)
    local cleaned = stripGeneratedGeometry(tags)
    if cleaned == "" then return "{" .. geom .. "}" end
    if not cleaned:find("{", 1, true) then return "{" .. cleaned .. geom .. "}" end
    local prefix, finalOverride = cleaned:match("^(.*){(\\[^}]*)}$")
    if finalOverride then return prefix .. "{" .. finalOverride .. geom .. "}" end
    -- A trailing comment block is not an override block; keep it intact and
    -- append geometry in a new override block.
    return cleaned .. "{" .. geom .. "}"
end


local DEFAULTS = {
    type_mode = "Frame",
    vertical_gap = 0,
    circ_rot = "Normal",
    circ_radio = 0,
    circ_track = 0,
    circ_invert = false,
    circ_delete = false
}

local SIGN_TYPE_ITEMS = {"Frame", "Duration"}
local SIGN_ROT_ITEMS = {"Normal", "Invertido", "Vertical"}
local SIGN_TYPE_ALIASES = { ["Duracion"] = "Duration", ["Duracao"] = "Duration" }
local SIGN_ROT_ALIASES = { ["Inverted"] = "Invertido" }

local function normalizeSignConfig(cfg)
    cfg = FunctionalTable.union(cfg or {}, DEFAULTS)
    cfg.type_mode = RheaFoundation.chooseAlias(cfg.type_mode, SIGN_TYPE_ALIASES, SIGN_TYPE_ITEMS, DEFAULTS.type_mode)
    cfg.circ_rot = RheaFoundation.chooseAlias(cfg.circ_rot, SIGN_ROT_ALIASES, SIGN_ROT_ITEMS, DEFAULTS.circ_rot)
    cfg.vertical_gap = tonumber(cfg.vertical_gap) or DEFAULTS.vertical_gap
    return cfg
end

local SO_CONFIG = RheaConfig.section("so", DEFAULTS)

local function prepareSignLine(subs, meta, styles, line)
    local ok = pcall(karaskel.preproc_line, subs, meta, styles, line)
    if not ok or not line.styleref then
        local style = styles[line.style] or styles["Default"]
        if not style then return false end
        line.styleref = style
        line.text_stripped = Rhea.visibleText(line.text or "")
        local data = RheaFoundation.tryParseLine(line)
        if not data then return false end
        local tags = data:getEffectiveTags(-1, false, true, true).tags
        local pos = tags.position
        line.x = pos and pos.x or 0
        line.y = pos and pos.y or 0
    end
    return line.styleref ~= nil
end

local function typewriterOffset(line, index, count, mode)
    local startMs = tonumber(line and line.start_time) or 0
    local endMs = tonumber(line and line.end_time) or startMs
    local duration = math.max(0, endMs - startMs)
    if mode == "Frame" and aegisub.frame_from_ms and aegisub.ms_from_frame then
        local okFrame, startFrame = pcall(aegisub.frame_from_ms, startMs)
        if okFrame and startFrame then
            local okLast, lastFrame = pcall(aegisub.frame_from_ms, math.max(startMs, endMs - 1))
            local targetFrame = okLast and lastFrame and math.min(startFrame + index, lastFrame) or startFrame + index
            local okTime, frameMs = pcall(aegisub.ms_from_frame, targetFrame)
            if okTime and frameMs then
                return math.max(0, math.min(math.max(0, duration - 1), math.floor(frameMs - startMs + 0.5)))
            end
        end
    end
    return math.max(0, math.min(math.max(0, duration - 1),
        math.floor(index * duration / math.max(1, count))))
end

local function applyTypewriter(subs, sel, cfg)
    local usedMarkers = usedSignMarkerIDs(subs)
    local cnt = 0
    local changedSelection = {}
    for _, i in ipairs(RheaFoundation.selectionDialogueIndices(subs, sel)) do
        local line = subs[i]
        local startMs = tonumber(line.start_time)
        local endMs = tonumber(line.end_time)
        if not line.comment and startMs and endMs and endMs > startMs then
            local tokens = Rhea.tokenize(line.text or "")
            local nchars = 0
            for _, tk in ipairs(tokens) do if tk.type == "char" then nchars = nchars + 1 end end
            if nchars > 0 then
                local out, idx = {}, 0
                for _, tk in ipairs(tokens) do
                    if tk.type == "tag" then
                        local cleaned = RheaFoundation.removeTags(tk.content, {"alpha","1a","2a","3a","4a"})
                        if cleaned ~= "{}" then out[#out + 1] = cleaned end
                    elseif tk.type == "break" then
                        out[#out + 1] = tk.content
                    else
                        local ts = typewriterOffset(line, idx, nchars, cfg.type_mode)
                        out[#out + 1] = string.format("{\\alpha&HFF&\\t(%d,%d,\\alpha&H00&)}%s", ts, ts + 1, tk.content)
                        idx = idx + 1
                    end
                end

                line.text = table.concat(out)
                stampEffect(line, generateMarkerID(usedMarkers))
                subs[i] = line
                cnt = cnt + 1
                changedSelection[#changedSelection + 1] = i
            end
        end
    end
    if cnt > 0 then aegisub.set_undo_point("SignOps: Typewriter") end
    return cnt, cnt > 0 and changedSelection or nil
end


local function applyVertical(subs, sel, cfg)
    local usedMarkers = usedSignMarkerIDs(subs)
    local meta, styles = karaskel.collect_head(subs, false)
    local lines = LineCollection(subs, sel, function(line)
        return Rhea.isDialogue(line) and not line.comment
    end)
    local replacements = {}
    local cnt = 0
    local verticalGap = tonumber(cfg.vertical_gap) or 0
    lines:runCallback(function(_, line)
        local markerID = generateMarkerID(usedMarkers)
        if not prepareSignLine(subs, meta, styles, line) then return end
        local px, py = LineOps.tagPair(line.text, "pos", line.x, line.y, true)
        local chars = {}
        local currentTags = ""
        local currentStyle = {}
        for key, value in pairs(line.styleref) do currentStyle[key] = value end
        for _, token in ipairs(Rhea.tokenize(line.text or "")) do
            if token.type == "tag" then
                currentTags = currentTags .. token.content
                RheaFoundation.applyInlineStyleTags(currentStyle, token.content)
            elseif token.type == "char" then
                local charStyle = {}
                for key, value in pairs(currentStyle) do charStyle[key] = value end
                chars[#chars + 1] = {content = token.content, tags = currentTags, style = charStyle}
            end
        end
        if #chars == 0 then return end
        local cy = 0
        local new_lines = {}
        for _, char in ipairs(chars) do
            local nline = Rhea.cloneLine(line)
            local _, chH = RheaFoundation.textExtents(char.style, char.content)
            local scaleY = tonumber(char.style and char.style.scale_y) or 100
            local chh = (tonumber(chH) or 0) * (scaleY / 100)
            local geom = string.format("\\an5\\pos(%.1f,%.1f)", px, py + cy)
            nline.text = tagsWithGeometry(char.tags, geom) .. char.content
            stampEffect(nline, markerID)
            cy = cy + chh + verticalGap
            new_lines[#new_lines + 1] = nline
        end
        if #new_lines > 0 then
            replacements[line] = new_lines
            cnt = cnt + 1
        end
    end, true)
    if cnt <= 0 then return 0 end
    local newSel = RheaFoundation.replaceCollectedLines(lines, replacements, true)
    if cnt > 0 then aegisub.set_undo_point("SignOps: Vertical") end
    return cnt, cnt > 0 and (newSel or sel) or nil
end

local function applyCircle(subs, sel, cfg)
    local usedMarkers = usedSignMarkerIDs(subs)
    local meta, styles = karaskel.collect_head(subs, false)
    local lines = LineCollection(subs, sel, function(line)
        return Rhea.isDialogue(line) and not line.comment
    end)
    local replacements, additions = {}, {}
    local cnt = 0

    lines:runCallback(function(_, line)
        local markerID = generateMarkerID(usedMarkers)
        if not prepareSignLine(subs, meta, styles, line) then return end

        local px, py, posCall = LineOps.tagPair(line.text, "pos", nil, nil, true)
        local ox, oy, orgCall = LineOps.tagPair(line.text, "org", nil, nil, true)
        if not (posCall and orgCall and px and py and ox and oy) then
        else

            local rad = math.sqrt((px - ox)^2 + (py - oy)^2) + (cfg.circ_radio or 0)
            local ang = RheaFoundation.atan2(py - oy, px - ox)
            if rad >= 1 then
                local parts = Rhea.tokenize(line.text)
                local cur_style = {}
                for k,v in pairs(line.styleref) do cur_style[k]=v end

                local letters = {}
                local aw = 0
                local ht = ""
                local bord_val = LineOps.tagNumber(line.text, "bord", line.styleref.outline or 0, true)
                local ro = rad + (cur_style.fontsize / 2.2)

                for _, p in ipairs(parts) do
                    if p.type == "tag" then
                        ht = ht .. p.content
                        RheaFoundation.applyInlineStyleTags(cur_style, p.content)
                    elseif p.type ~= "break" then
                        local ch = p.content
                        local w = RheaFoundation.textExtents(cur_style, ch)
                        local sx = cur_style.scale_x / 100
                        local ar = (w * sx) + ((cur_style.spacing or 0) * sx) + (cfg.circ_track or 0) + (bord_val * 2 * sx)
                        local ac = ar / ro
                        table.insert(letters, {char = ch, angle_rad = ac, tags = ht})
                        aw = aw + ac
                    end
                end

                if #letters > 0 then aw = aw - ((cfg.circ_track or 0) / ro) end
                local pd = (py < oy) and 1 or -1
                if cfg.circ_invert then pd = pd * -1 end
                local acur = ang - (pd * (aw / 2))

                local new_lines = {}
                for _, let in ipairs(letters) do
                    if not let.char:match("^%s*$") then
                        local am = acur + (pd * (let.angle_rad / 2))
                        local fx = ox + rad * math.cos(am)
                        local fy = oy + rad * math.sin(am)
                        local rot = -math.deg(am) - 90
                        if cfg.circ_rot == "Vertical" then rot = 0
                        elseif cfg.circ_rot == "Invertido" then rot = rot + 180 end

                        local nline = Rhea.cloneLine(line)
                        local geom = string.format("\\an5\\pos(%.2f,%.2f)\\frz%.2f", fx, fy, rot)
                        nline.text = tagsWithGeometry(let.tags, geom) .. let.char
                        nline.layer = (tonumber(line.layer) or 0) + 1
                        stampEffect(nline, markerID)
                        table.insert(new_lines, nline)
                    end
                    acur = acur + (pd * let.angle_rad)
                end

                if #new_lines > 0 then
                    if cfg.circ_delete then
                        replacements[line] = new_lines
                    else
                        line.comment = true
                        line.text = "{Origin} " .. line.text
                        additions[line] = new_lines
                    end
                    cnt = cnt + 1
                end
            end
        end
    end)
    if cnt <= 0 then return 0 end
    if cfg.circ_delete then
        local newSel = RheaFoundation.replaceCollectedLines(lines, replacements, true)
        if cnt > 0 then aegisub.set_undo_point("SignOps: Circle") end
        return cnt, newSel or sel
    else
        local newSel = RheaFoundation.insertCollectedLinesAfter(lines, additions, true)
        if cnt > 0 then aegisub.set_undo_point("SignOps: Circle") end
        return cnt, newSel or sel
    end
end


local function parseVectorClip(text)
    return RheaFoundation.clipCommands(RheaFoundation.firstClipTag(text))
end

local function applyCurve(subs, sel, cfg)
    local usedMarkers = usedSignMarkerIDs(subs)
    local meta, styles = karaskel.collect_head(subs, false)
    local lines = LineCollection(subs, sel, function(line)
        return Rhea.isDialogue(line) and not line.comment
    end)
    local replacements = {}

    local globalClipCmds = nil
    for _, i in ipairs(sel) do
        globalClipCmds = parseVectorClip(subs[i].text)
        if globalClipCmds then break end
    end
    if not globalClipCmds then
        showMsg(L("msg_no_vector_curve"))
        return 0
    end
    local cnt = 0

    lines:runCallback(function(_, line)
        local markerID = generateMarkerID(usedMarkers)
        local clipCmds = parseVectorClip(line.text) or globalClipCmds
        local sampledPath, totalLen = RheaFoundation.samplePath(clipCmds, 40)
        if totalLen > 0 then
            if not prepareSignLine(subs, meta, styles, line) then return end

            local parts = Rhea.tokenize(line.text)
            local cur_style = {}
            for k,v in pairs(line.styleref) do cur_style[k]=v end

            local letters = {}
            local total_w = 0
            local ht = ""
            local bord_val = LineOps.tagNumber(line.text, "bord", line.styleref.outline or 0, true)

            for _, p in ipairs(parts) do
                if p.type == "tag" then
                    ht = ht .. p.content
                    RheaFoundation.applyInlineStyleTags(cur_style, p.content)
                elseif p.type ~= "break" then
                    local ch = p.content
                    local w = RheaFoundation.textExtents(cur_style, ch)
                    local sx = cur_style.scale_x / 100
                    local ar = (w * sx) + ((cur_style.spacing or 0) * sx) + (bord_val * 2 * sx)
                    table.insert(letters, {char = ch, width = ar, tags = ht})
                    total_w = total_w + ar
                end
            end

            local new_lines = {}
            local curDist = (totalLen - total_w) / 2
            for _, let in ipairs(letters) do
                if not let.char:match("^%s*$") then
                    local charCenterDist = curDist + let.width / 2
                    local pathPt = RheaFoundation.pointOnPath(sampledPath, charCenterDist)
                    if pathPt then
                        local rot = -math.deg(pathPt.angle)
                        local px = pathPt.p.x
                        local py = pathPt.p.y

                        local nline = Rhea.cloneLine(line)
                        local geom = string.format("\\an5\\pos(%.2f,%.2f)\\frz%.2f", px, py, rot)
                        nline.text = tagsWithGeometry(let.tags, geom) .. let.char
                        nline.layer = (tonumber(line.layer) or 0) + 1
                        stampEffect(nline, markerID)
                        table.insert(new_lines, nline)
                    end
                end
                curDist = curDist + let.width
            end

            if #new_lines > 0 then
                replacements[line] = new_lines
                cnt = cnt + 1
            end
        end
    end)
    if cnt <= 0 then return 0 end
    local newSel = RheaFoundation.replaceCollectedLines(lines, replacements, true)
    if cnt > 0 then aegisub.set_undo_point("SignOps: Curve Text") end
    return cnt, newSel or sel
end

local function cleanSiO(subs, sel)
    local newSel, changed, count = RheaFoundation.cleanByMarker(subs, sel, "all", "SiO", nil, nil, "SignOps: Clean SiO-lines")
    return count or 0, changed and newSel or nil
end


local function so_dispatch(subs, sel, opts)
    if not sel or #sel == 0 then return false end
    _so_reset()
    local cfg = SO_CONFIG.read()
    cfg = normalizeSignConfig(FunctionalTable.union(opts or {}, cfg, DEFAULTS))
    SO_CONFIG.write(cfg)
    local op = opts and opts.op or ""
    local n, newSel = 0, nil
    if     op == "typewriter"    then n, newSel = applyTypewriter(subs, sel, cfg)
    elseif op == "vertical_drop" then n, newSel = applyVertical(subs, sel, cfg)
    elseif op == "circle_text"   then n, newSel = applyCircle(subs, sel, cfg)
    elseif op == "curve_text"    then n, newSel = applyCurve(subs, sel, cfg)
    elseif op == "clean_sio"     then n, newSel = cleanSiO(subs, sel) end
    n = n or 0
    return n > 0 and (newSel or true) or false, n > 0
end

RheaOps.Sign.run = so_dispatch
RheaOps.Sign.loadConfig = function()
    local cfg = SO_CONFIG.read()
    return normalizeSignConfig(cfg)
end
RheaOps.Sign.defaults = DEFAULTS

end

do


local function detectLerpTag(text)
    return RheaFoundation.detectGBCTag(text) or "color1"
end

local function processLine(line, newVisible, doLerp)
    local sourceText = line.text or ""
    local cleanText = RheaFoundation.stripAutoMarkers(sourceText)
    if cleanText ~= sourceText then line.text = cleanText end
    local ass = RheaFoundation.tryParseLine(line)
    if not ass then return false end
    if newVisible ~= nil then
        if RheaFoundation.replaceVisibleText(ass, newVisible) then
            ass:commit(line)
            ass = RheaFoundation.tryParseLine(line)
            if not ass then return false end
        end
    end
    local regenerated = false
    local protectedBreaks = false
    if doLerp then
        local protectedText = Rhea.protectVisibleBreaks(line.text)
        if protectedText ~= line.text then
            line.text = protectedText
            protectedBreaks = true
            ass = RheaFoundation.tryParseLine(line)
            if not ass then
                line.text = Rhea.restoreVisibleBreaks(line.text)
                return false
            end
        end
        regenerated = RheaFoundation.lerpLine(ass, detectLerpTag(sourceText))
    end
    ass:commit(line)
    if protectedBreaks then line.text = Rhea.restoreVisibleBreaks(line.text) end
    return regenerated
end

local function groupVisible(lines, opts)
    local records, order, groups = {}, {}, {}
    local stats = { omit_vec = 0, omit_cap = 0 }
    local skipVec = opts.skip_vec
    local useCap, capLimit = opts.use_cap, opts.cap_limit or 150
    lines:runCallback(function(_, line, i)
        if not line.text or line.text == "" then return end
        if skipVec and Rhea.isVectorLine(line.text) then
            stats.omit_vec = stats.omit_vec + 1; return
        end
        local cleanText = RheaFoundation.stripAutoMarkers(line.text)
        local ass = RheaFoundation.tryParseLine(cleanText)
        if not ass then return end
        local visible = RheaFoundation.visibleFromASS(ass)
        if visible == "" then return end
        if useCap and #visible > capLimit then
            stats.omit_cap = stats.omit_cap + 1; return
        end
        local isGBC = line.text:find("{*", 1, true) ~= nil
        records[#records + 1] = { visible = visible, line = line, idx = i, isGBC = isGBC }
    end)
    local grouped = FunctionalList.groupBy(records, "visible")
    for _, record in ipairs(records) do
        if not groups[record.visible] then
            groups[record.visible] = grouped[record.visible]
            order[#order + 1] = record.visible
        end
    end
    return groups, order, stats
end

local function main(sub, sel)
    resolveConfig()
    if not sel or #sel == 0 then showMsg(L("err_no_selection")); return false end

    local cfgDlg = {
        {class="label", x=0, y=0, width=4, height=1, label=L("signs_editor_title")},
        {class="checkbox", x=0, y=1, width=3, name="skip_vec", label=L("signs_skip_vec"), value=true},
        {class="checkbox", x=0, y=2, width=3, name="auto_gbc", label=L("signs_auto_gbc"), value=true},
        {class="checkbox", x=0, y=3, width=2, name="use_cap", label=L("signs_use_cap"), value=false},
        {class="intedit", x=2, y=3, width=1, name="cap_limit", value=150, min=1, max=5000},
    }

    local continue, cancel = L("btn_continue"), L("btn_cancel")
    local btn1, res1 = aegisub.dialog.display(cfgDlg, {continue, cancel}, {ok=continue, close=cancel})
    if btn1 ~= continue then return false end

    local lines = LineCollection(sub, sel)
    local groups, order, stats = groupVisible(lines, res1)

    if #order == 0 then
        showMsg(L("signs_no_editable"))
        return false
    end

    local gbcCount, totalGrouped = 0, 0
    for _, vis in ipairs(order) do
        for _, d in ipairs(groups[vis]) do
            totalGrouped = totalGrouped + 1
            if d.isGBC then gbcCount = gbcCount + 1 end
        end
    end

    local originalText = table.concat(order, "\n")
    local info = string.format(L("signs_info"), #order, totalGrouped, gbcCount)
    if stats.omit_vec > 0 then info = info .. string.format(L("signs_skipped_vectors"), stats.omit_vec) end
    if stats.omit_cap > 0 then info = info .. string.format(L("signs_skipped_over_limit"), stats.omit_cap) end

    local editDlg = {
        {class="label", x=0, y=0, width=40, height=1, label=L("signs_original")},
        {class="textbox", x=0, y=1, width=40, height=14, name="original", text=originalText},
        {class="label", x=41, y=0, width=40, height=1, label=L("signs_modified")},
        {class="textbox", x=41, y=1, width=40, height=14, name="modified", text=originalText},
        {class="label", x=0, y=15, width=81, height=1, label=info},
        {class="checkbox", x=0, y=16, width=40, name="do_gbc", label=L("signs_regen_gbc"), value=res1.auto_gbc},
    }

    local apply = L("btn_apply")
    local btn2, res2 = aegisub.dialog.display(editDlg, {apply, cancel}, {ok=apply, close=cancel})
    if btn2 ~= apply then return false end

    local modifiedLines = {}
    for line in (res2.modified .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        table.insert(modifiedLines, line)
    end
    while #modifiedLines > #order and modifiedLines[#modifiedLines] == "" do
        table.remove(modifiedLines)
    end

    if #modifiedLines ~= #order then
        showMsg(string.format(L("signs_line_mismatch"), #order, #modifiedLines))
        return false
    end

    local remap = {}
    for i, orig in ipairs(order) do remap[orig] = modifiedLines[i] end

    local modCount, gbcRegen = 0, 0
    for vis, dataList in pairs(groups) do
        local newVis = remap[vis]
        if newVis and newVis ~= vis then
            for _, d in ipairs(dataList) do
                local regenerated = processLine(d.line, newVis, d.isGBC and res2.do_gbc)
                if regenerated then gbcRegen = gbcRegen + 1 end
                modCount = modCount + 1
            end
        end
    end
    lines:replaceLines()

    aegisub.set_undo_point("Signs Editor")
    return true
end


RheaOps.Tools.massSigns = main
end


local function fastSignsCleanText(text)
    local cleaned = Rhea.stripTags(text):gsub("\\n", "\\N")
    cleaned = cleaned:gsub("%s*\\N%s*", "\\N"):gsub("^\\N+", ""):gsub("\\N+$", "")
    return cleaned
end

local function fastSignsRes(meta)
    local xres = tonumber(meta and (meta.res_x or meta.PlayResX))
    local yres = tonumber(meta and (meta.res_y or meta.PlayResY))
    if (not xres or xres <= 0 or not yres or yres <= 0) and aegisub.video_size then
        local ok, videoX, videoY = pcall(aegisub.video_size)
        if ok then
            xres = xres and xres > 0 and xres or tonumber(videoX)
            yres = yres and yres > 0 and yres or tonumber(videoY)
        end
    end
    if not xres or xres <= 0 or not yres or yres <= 0 then return nil, nil end
    return xres, yres
end

local function fastSignsMeasure(line, style, text)
    local bw, bh = RheaFoundation.lineBoundsSize(line, text, style)
    return bw or 0, bh or ((style and style.fontsize) or 0)
end

local function fastSignsRect(w, h)
    local wi = math.max(1, math.floor((tonumber(w) or 0) + 0.5))
    local hi = math.max(1, math.floor((tonumber(h) or 0) + 0.5))
    return string.format("m 0 0 l %d 0 l %d %d l 0 %d", wi, wi, hi, hi)
end

local function fastSignsEffect(effect, marker)
    local cleaned = tostring(effect or ""):gsub("%[FS%-%d+%]", "")
    cleaned = Rhea.trim(cleaned):gsub("%s+", " ")
    return cleaned ~= "" and (marker .. " " .. cleaned) or marker
end

local function fastSignsConfig()
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        if tostring(k):match("^fastsign_") then cfg[k] = current_config[k] ~= nil and current_config[k] or v end
    end
    cfg.fastsign_box_alpha = RheaFoundation.sanitizeAlpha(cfg.fastsign_box_alpha, DEFAULT_CONFIG.fastsign_box_alpha)
    cfg.fastsign_glow_alpha = RheaFoundation.sanitizeAlpha(cfg.fastsign_glow_alpha, DEFAULT_CONFIG.fastsign_glow_alpha)
    cfg.fastsign_fade_ms = RheaFoundation.configNumber(cfg.fastsign_fade_ms, DEFAULT_CONFIG.fastsign_fade_ms, 0)
    cfg.fastsign_margin_h = RheaFoundation.configNumber(cfg.fastsign_margin_h, DEFAULT_CONFIG.fastsign_margin_h, 0)
    cfg.fastsign_margin_v = RheaFoundation.configNumber(cfg.fastsign_margin_v, DEFAULT_CONFIG.fastsign_margin_v, 0)
    cfg.fastsign_top_offset = RheaFoundation.configNumber(cfg.fastsign_top_offset, DEFAULT_CONFIG.fastsign_top_offset, 0)
    cfg.fastsign_horz_gap = RheaFoundation.configNumber(cfg.fastsign_horz_gap, DEFAULT_CONFIG.fastsign_horz_gap, 0)
    cfg.fastsign_max_width = RheaFoundation.configNumber(cfg.fastsign_max_width, DEFAULT_CONFIG.fastsign_max_width, 10, 100)
    cfg.fastsign_box_blur = RheaFoundation.configNumber(cfg.fastsign_box_blur, DEFAULT_CONFIG.fastsign_box_blur, 0)
    cfg.fastsign_glow_border = RheaFoundation.configNumber(cfg.fastsign_glow_border, DEFAULT_CONFIG.fastsign_glow_border, 0)
    cfg.fastsign_glow_blur = RheaFoundation.configNumber(cfg.fastsign_glow_blur, DEFAULT_CONFIG.fastsign_glow_blur, 0)
    cfg.fastsign_text_blur = RheaFoundation.configNumber(cfg.fastsign_text_blur, DEFAULT_CONFIG.fastsign_text_blur, 0)
    return cfg
end

local function runFastSigns(subs, sel)
    resolveConfig()
    if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end
    local cfg = fastSignsConfig()
    local meta, styles = karaskel.collect_head(subs, false)
    local vid_w = fastSignsRes(meta)
    if not vid_w then showMsg("FastSigns could not determine the script or video resolution."); return end
    local clusters = {}
    local rawCandidates = {}
    local lines = LineCollection(subs, sel, function(line)
        return Rhea.isDialogue(line) and not line.comment and not Rhea.readMarker(line, "FS")
    end)
    lines:runCallback(function(_, line)
        if line.text and line.text ~= "" and tonumber(line.end_time) and tonumber(line.start_time)
            and line.end_time > line.start_time then
            local clean = fastSignsCleanText(line.text)
            rawCandidates[#rawCandidates + 1] = { idx = line.number, line = line, clean = clean }
        end
    end)
    local candidates = FunctionalList.filter(rawCandidates, function(item)
        return item.clean ~= "" and not item.clean:match("^%s*$")
    end)
    if #candidates == 0 then
        showMsg("FastSigns found no eligible non-comment dialogue lines.")
        return false
    end
    table.sort(candidates, function(a, b)
        local as, bs = a.line.start_time or 0, b.line.start_time or 0
        local ae, be = a.line.end_time or 0, b.line.end_time or 0
        if as ~= bs then return as < bs end
        if ae ~= be then return ae < be end
        return a.idx < b.idx
    end)
    for seq, item in ipairs(candidates) do
        local line = item.line
        item.marker = string.format("[FS-%03d]", seq)
        local added = false
        local startTime = line.start_time or 0
        local endTime = line.end_time or startTime
        if #clusters > 0 then
            local last = clusters[#clusters]
            if startTime < last.end_time and endTime > last.start_time then
                last.lines[#last.lines + 1] = item
                last.end_time = math.max(last.end_time, endTime)
                added = true
            end
        end
        if not added then
            clusters[#clusters + 1] = {
                start_time = startTime,
                end_time = endTime,
                lines = { item },
            }
        end
    end
    local outputItems = {}
    for _, cluster in ipairs(clusters) do
        local total_w = 0
        for _, item in ipairs(cluster.lines) do
            local style = styles[item.line.style] or styles.Default
            local text_w, text_h = fastSignsMeasure(item.line, style, item.clean)
            local box_w = math.min(text_w + cfg.fastsign_margin_h * 2, vid_w * (cfg.fastsign_max_width / 100))
            local box_h = text_h + cfg.fastsign_margin_v * 2
            item.box_w, item.box_h = box_w, box_h
            total_w = total_w + box_w
        end
        total_w = total_w + cfg.fastsign_horz_gap * (#cluster.lines - 1)
        local current_x = (vid_w / 2) - (total_w / 2)
        for _, item in ipairs(cluster.lines) do
            item.center_x = current_x + item.box_w / 2
            item.center_y = cfg.fastsign_top_offset + item.box_h / 2
            current_x = current_x + item.box_w + cfg.fastsign_horz_gap
        end
    end
    for _, cluster in ipairs(clusters) do
        for _, item in ipairs(cluster.lines) do outputItems[#outputItems + 1] = item end
    end
    local additions = {}
    for _, item in ipairs(outputItems) do
        local line = item.line
        local lineDuration = math.max(0, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
        local fadeMs = math.min(cfg.fastsign_fade_ms, math.floor(lineDuration / 2))
        local marked_effect = fastSignsEffect(line.effect, item.marker)
        local shape_x = item.center_x - item.box_w / 2
        local shape_y = item.center_y - item.box_h / 2
        local box_shape = fastSignsRect(item.box_w, item.box_h)
        local base_layer = tonumber(line.layer) or 0
        local box = Rhea.cloneLine(line)
        local glow = Rhea.cloneLine(line)
        local text = Rhea.cloneLine(line)
        box.layer = base_layer
        box.effect = marked_effect
        box.comment = false
        box.text = string.format("{\\an7\\pos(%.1f,%.1f)\\fad(%d,%d)\\bord0\\shad0\\blur%.2f\\fscx100\\fscy100\\1c%s\\1a&H%s&\\p1}%s",
            shape_x, shape_y, fadeMs, fadeMs, cfg.fastsign_box_blur, Rhea.htmlToAss(cfg.fastsign_box_color), cfg.fastsign_box_alpha, box_shape)
        glow.layer = base_layer + 1
        glow.effect = marked_effect
        glow.comment = false
        glow.text = string.format("{\\an5\\pos(%.1f,%.1f)\\fad(%d,%d)\\bord%.2f\\shad0\\blur%.2f\\1c%s\\3c%s\\1a&HFF&\\3a&H%s&}%s",
            item.center_x, item.center_y, fadeMs, fadeMs, cfg.fastsign_glow_border, cfg.fastsign_glow_blur,
            Rhea.htmlToAss(cfg.fastsign_text_color), Rhea.htmlToAss(cfg.fastsign_glow_color), cfg.fastsign_glow_alpha, item.clean)
        text.layer = base_layer + 2
        text.effect = marked_effect
        text.comment = false
        text.text = string.format("{\\an5\\pos(%.1f,%.1f)\\fad(%d,%d)\\bord0\\shad0\\blur%.2f\\1c%s}%s",
            item.center_x, item.center_y, fadeMs, fadeMs, cfg.fastsign_text_blur, Rhea.htmlToAss(cfg.fastsign_text_color), item.clean)
        line.comment = true
        line.effect = marked_effect
        additions[line] = {box, glow, text}
    end
    RheaFoundation.insertCollectedLinesAfter(lines, additions)
    aegisub.set_undo_point("Rhea Signs - FastSigns")
end

RheaOps.Tools.fastSigns = runFastSigns


local TagOps = RheaOps.TagOps

local TAGOPS_DEFS = {
    { key="pos",   label="pos",    names={"pos"},        remove={"pos","move"},    animatable=false },
    { key="move",  label="move",   names={"move"},       remove={"move","pos"},    animatable=false },
    { key="org",   label="org",    names={"org"},        remove={"org"},           animatable=false },
    { key="clip",  label="clip",   names={"clip"},       remove={"clip","iclip"},  animatable=true  },
    { key="iclip", label="iclip",  names={"iclip"},      remove={"iclip","clip"},  animatable=true  },
    { key="fad",   label="fad",    names={"fad"},        remove={"fad","fade"},    animatable=false },
    { key="fade",  label="fade",   names={"fade"},       remove={"fade","fad"},    animatable=false },
    { key="t",     label="t",      names={"t"},          remove={"t"},             animatable=false },
    { key="r",     label="r",      names={"r"},          remove={"r"},             animatable=false },
    { key="an",    label="an",     names={"an"},         remove={"an","a"},        animatable=false },
    { key="a",     label="a",      names={"a"},          remove={"a","an"},        animatable=false },
    { key="q",     label="q",      names={"q"},          remove={"q"},             animatable=false },
    { key="fn",    label="fn",     names={"fn"},         remove={"fn"},            animatable=false },
    { key="fs",    label="fs",     names={"fs"},         remove={"fs"},            animatable=true  },
    { key="fsp",   label="fsp",    names={"fsp"},        remove={"fsp"},           animatable=true  },
    { key="fscx",  label="fscx",   names={"fscx"},       remove={"fscx"},          animatable=true  },
    { key="fscy",  label="fscy",   names={"fscy"},       remove={"fscy"},          animatable=true  },
    { key="frz",   label="frz/fr", names={"frz","fr"},   remove={"frz","fr"},      animatable=true  },
    { key="frx",   label="frx",    names={"frx"},        remove={"frx"},           animatable=true  },
    { key="fry",   label="fry",    names={"fry"},        remove={"fry"},           animatable=true  },
    { key="fax",   label="fax",    names={"fax"},        remove={"fax"},           animatable=true  },
    { key="fay",   label="fay",    names={"fay"},        remove={"fay"},           animatable=true  },
    { key="bord",  label="bord",   names={"bord"},       remove={"bord"},          animatable=true  },
    { key="xbord", label="xbord",  names={"xbord"},      remove={"xbord"},         animatable=true  },
    { key="ybord", label="ybord",  names={"ybord"},      remove={"ybord"},         animatable=true  },
    { key="shad",  label="shad",   names={"shad"},       remove={"shad"},          animatable=true  },
    { key="xshad", label="xshad",  names={"xshad"},      remove={"xshad"},         animatable=true  },
    { key="yshad", label="yshad",  names={"yshad"},      remove={"yshad"},         animatable=true  },
    { key="blur",  label="blur",   names={"blur"},       remove={"blur"},          animatable=true  },
    { key="be",    label="be",     names={"be"},         remove={"be"},            animatable=true  },
    { key="b",     label="b",      names={"b"},          remove={"b"},             animatable=false },
    { key="i",     label="i",      names={"i"},          remove={"i"},             animatable=false },
    { key="u",     label="u",      names={"u"},          remove={"u"},             animatable=false },
    { key="s",     label="s",      names={"s"},          remove={"s"},             animatable=false },
    { key="c",     label="c/1c",   names={"c","1c"},     remove={"c","1c"},        animatable=true  },
    { key="2c",    label="2c",     names={"2c"},         remove={"2c"},            animatable=true  },
    { key="3c",    label="3c",     names={"3c"},         remove={"3c"},            animatable=true  },
    { key="4c",    label="4c",     names={"4c"},         remove={"4c"},            animatable=true  },
    { key="alpha", label="alpha",  names={"alpha"},      remove={"alpha"},         animatable=true  },
    { key="1a",    label="1a",     names={"1a"},         remove={"1a"},            animatable=true  },
    { key="2a",    label="2a",     names={"2a"},         remove={"2a"},            animatable=true  },
    { key="3a",    label="3a",     names={"3a"},         remove={"3a"},            animatable=true  },
    { key="4a",    label="4a",     names={"4a"},         remove={"4a"},            animatable=true  },
    { key="k",     label="k",      names={"k"},          remove={"k"},             animatable=false },
    { key="kf",    label="kf/K",   names={"kf","K"},     remove={"kf","K"},        animatable=false },
    { key="ko",    label="ko",     names={"ko"},         remove={"ko"},            animatable=false },
    { key="p",     label="p",      names={"p"},          remove={"p"},             animatable=false },
    { key="pbo",   label="pbo",    names={"pbo"},        remove={"pbo"},           animatable=false },
    { key="fe",    label="fe",     names={"fe"},         remove={"fe"},            animatable=false },
}

local TAGOPS_BY_KEY, TAGOPS_NAME_TO_KEYS = {}, {}
for _, def in ipairs(TAGOPS_DEFS) do
    TAGOPS_BY_KEY[def.key] = def
    for _, n in ipairs(def.names) do
        TAGOPS_NAME_TO_KEYS[n] = TAGOPS_NAME_TO_KEYS[n] or {}
        TAGOPS_NAME_TO_KEYS[n][#TAGOPS_NAME_TO_KEYS[n] + 1] = def.key
    end
end
TagOps.U.alert = showMsg

local function tagopsAppendLeadingTags(text, payload)
    text = tostring(text or "")
    payload = tostring(payload or "")
    if payload == "" then return text end
    local pos, lastClose, leadingClose = 1, nil, nil
    while text:sub(pos, pos) == "{" do
        local close = text:find("}", pos + 1, true)
        if not close then break end
        leadingClose = close
        if text:sub(pos + 1, pos + 1) ~= "*" then lastClose = close end
        pos = close + 1
    end
    if lastClose then
        return text:sub(1, lastClose - 1) .. payload .. "}" .. text:sub(lastClose + 1)
    end
    if leadingClose then
        return text:sub(1, leadingClose) .. "{" .. payload .. "}" .. text:sub(leadingClose + 1)
    end
    return "{" .. payload .. "}" .. text
end

local function tagopsRemoveNames(selected)
    return FunctionalList.reduce(TAGOPS_DEFS, {}, function(names, def)
        if selected[def.key] then FunctionalList.makeSet(def.remove or def.names, names) end
        return names
    end)
end

local function tagopsExtractTags(text, selected, allBlocks)
    local out, found = {}, {}
    for blockIndex, block in ipairs(RheaFoundation.iterTagBlocks(text)) do
        if allBlocks or blockIndex == 1 then
            for _, tag in ipairs(RheaFoundation.parseTagBlock(block.content)) do
                local keys = TAGOPS_NAME_TO_KEYS[tag.name]
                if keys then
                    for _, key in ipairs(keys) do
                        if selected[key] then
                            out[#out + 1] = tag.raw
                            found[key] = true
                            break
                        end
                    end
                end
            end
        end
        if not allBlocks then break end
    end
    return table.concat(out), found
end

local function tagopsHasAnySelected(selected)
    for _ in pairs(selected or {}) do return true end
    return false
end

local function tagopsMergeFound(dst, src)
    for key, value in pairs(src or {}) do
        if value then dst[key] = true end
    end
end

function TagOps.opCopy(subs, sel, opts)
    if not sel or #sel < 2 then TagOps.U.alert(L("tagops_err_copy_select")); return false end
    opts = opts or {}
    local selected = opts.selected or {}
    if not tagopsHasAnySelected(selected) then TagOps.U.alert(L("tagops_err_select_tag")); return false end
    local groups = RheaFoundation.selectionCopyGroups(subs, sel)
    if #groups == 0 then TagOps.U.alert(L("tagops_err_copy_select")); return false end

    local names = tagopsRemoveNames(selected)
    local changed, found = 0, {}
    local anySourceTags = false
    for _, group in ipairs(groups) do
        if #group.targets > 0 then
            local source = subs[group.source]
            local tags, groupFound = tagopsExtractTags(source.text or "", selected, opts.all_blocks)
            if tags ~= "" then
                anySourceTags = true
                tagopsMergeFound(found, groupFound)
                for _, i in ipairs(group.targets) do
                    local line = subs[i]
                    local text = line.text or ""
                    if opts.replace then text = RheaFoundation.removeTags(text, names) end
                    local nextText = RheaFoundation.insertTags(text, tags, opts.append and "append" or nil)
                    if nextText ~= line.text then
                        line.text = nextText
                        subs[i] = line
                        changed = changed + 1
                    end
                end
            end
        end
    end
    if not anySourceTags then TagOps.U.alert(L("tagops_err_source_tag")); return false end
    if changed == 0 then TagOps.U.alert(L("tagops_copy_no_change")); return false end
    aegisub.set_undo_point("TagOps - Copy")
    if opts.info then
        local copied = FunctionalList.map(FunctionalList.filter(TAGOPS_DEFS, function(def)
            return found[def.key]
        end), function(def) return def.label end)
        TagOps.U.alert(string.format("%s: %s\n%s: %d", L("tagops_copied"), table.concat(copied, ", "), L("tagops_targets"), changed))
    end
    return true
end

local function tagopsTagSelected(name, selected)
    local keys = TAGOPS_NAME_TO_KEYS[name]
    if not keys then return false end
    for _, key in ipairs(keys) do if selected[key] then return true end end
    return false
end

local function tagopsIsOverrideBlock(content)
    return tostring(content or ""):match("^[*>]?\\") ~= nil
end

local function tagopsKeepOnlyContent(content, selected)
    content = tostring(content or "")
    local prefix = ""
    local first = content:sub(1, 1)
    if first == "*" or first == ">" then
        prefix = first
        content = content:sub(2)
    end

    local out, pos = {}, 1
    for _, tag in ipairs(RheaFoundation.parseTagBlock(content)) do
        out[#out + 1] = content:sub(pos, tag.startPos - 1)
        if tagopsTagSelected(tag.name, selected) then
            out[#out + 1] = tag.raw
        end
        pos = tag.endPos + 1
    end
    out[#out + 1] = content:sub(pos)

    local cleaned = table.concat(out)
    if cleaned:match("^%s*$") then return "" end
    return prefix .. cleaned
end

local function tagopsKeepOnlyText(text, selected)
    text = tostring(text or "")
    local out, pos = {}, 1
    for _, block in ipairs(RheaFoundation.iterTagBlocks(text)) do
        out[#out + 1] = text:sub(pos, block.openPos - 1)
        if tagopsIsOverrideBlock(block.content) then
            local cleaned = tagopsKeepOnlyContent(block.content, selected)
            if cleaned ~= "" then out[#out + 1] = "{" .. cleaned .. "}" end
        else
            out[#out + 1] = text:sub(block.openPos, block.closePos)
        end
        pos = block.closePos + 1
    end
    out[#out + 1] = text:sub(pos)
    return (table.concat(out):gsub("{}", ""))
end

function TagOps.opKeepOnly(subs, sel, opts)
    if not sel or #sel == 0 then TagOps.U.alert(L("tagops_err_adjust_select")); return false end
    opts = opts or {}
    local selected = opts.selected or {}
    if not tagopsHasAnySelected(selected) then TagOps.U.alert(L("tagops_err_select_tag")); return false end

    local changed = 0
    for _, i in ipairs(sel) do
        local line = subs[i]
        if Rhea.isDialogue(line) then
            local nextText = tagopsKeepOnlyText(line.text or "", selected)
            if nextText ~= line.text then
                line.text = nextText
                subs[i] = line
                changed = changed + 1
            end
        end
    end
    if changed == 0 then
        TagOps.U.alert(L("tagops_keep_only_no_change"))
        return false
    end
    aegisub.set_undo_point("TagOps - Keep Only")
    if opts.info then TagOps.U.alert(string.format(L("tagops_keep_only_changed"), changed)) end
    return true
end

local TAGOPS_AUTO_ADJUST_KEYS = {
    fs=true, fsp=true, fscx=true, fscy=true,
    frz=true, frx=true, fry=true, fax=true, fay=true,
    bord=true, xbord=true, ybord=true,
    shad=true, xshad=true, yshad=true,
    blur=true, be=true, pbo=true,
}

local TAGOPS_MANUAL_ADJUST_KEYS = {
    pos=true, move=true, org=true, clip=true, iclip=true,
    fad=true, fade=true, t=true, an=true, a=true, q=true,
    fs=true, fsp=true, fscx=true, fscy=true,
    frz=true, frx=true, fry=true, fax=true, fay=true,
    bord=true, xbord=true, ybord=true,
    shad=true, xshad=true, yshad=true,
    blur=true, be=true, k=true, kf=true, ko=true, pbo=true,
}

local TAGOPS_STYLE_ADJUST_ORDER = {"fs", "fsp", "fscx", "fscy", "bord", "shad"}
local TAGOPS_STYLE_ADJUST = {
    fs   = { tag="fs",   field="fontsize", default=20 },
    fsp  = { tag="fsp",  field="spacing",  default=0  },
    fscx = { tag="fscx", field="scale_x",  default=100 },
    fscy = { tag="fscy", field="scale_y",  default=100 },
    bord = { tag="bord", field="outline",  default=0  },
    shad = { tag="shad", field="shadow",   default=0  },
}

local TAGOPS_NUM_VALUE_PATTERN = "[%+%-]?%d*%.?%d+"
local TAGOPS_PERSPECTIVE_REPROJECT_KEYS = { fs=true, fsp=true, fscx=true, fscy=true }

local function tagopsAdjustKeyForName(name)
    for _, key in ipairs(TAGOPS_NAME_TO_KEYS[name] or {}) do
        if TAGOPS_AUTO_ADJUST_KEYS[key] then return key end
    end
    return nil
end

local function tagopsTransformInner(token)
    local tagStart = tostring(token or ""):find("\\", 4, true)
    if not tagStart then return nil end
    local tagEnd = token:sub(-1) == ")" and #token - 1 or #token
    return token:sub(tagStart, tagEnd)
end

local function tagopsCollectAdjustKeysFromBlock(block, selected)
    local pending, cursor = { block }, 1
    while cursor <= #pending do
        local current = pending[cursor]
        cursor = cursor + 1
        for _, tag in ipairs(RheaFoundation.parseTagBlock(current)) do
            if tag.name == "t" then
                local inner = tagopsTransformInner(tag.raw)
                if inner then pending[#pending + 1] = inner end
            else
                local key = tagopsAdjustKeyForName(tag.name)
                if key and tostring(tag.value or ""):match(TAGOPS_NUM_VALUE_PATTERN) then
                    selected[key] = true
                end
            end
        end
    end
end

local function tagopsCollectAdjustKeysFromText(text, selected)
    for _, block in ipairs(RheaFoundation.iterTagBlocks(text)) do
        tagopsCollectAdjustKeysFromBlock(block.content, selected)
    end
end

local function tagopsLineStyle(line, styles)
    if not line then return nil end
    return line.styleref or line.styleRef or (styles and (styles[line.style] or styles.Default)) or nil
end

local function tagopsStyleDefaultValue(style, spec)
    if not style or not spec then return nil end
    local value = tonumber(style[spec.field])
    if value == nil then value = spec.default end
    return value
end

local function tagopsCollectStyleAdjustKeys(line, styles, selected)
    local style = tagopsLineStyle(line, styles)
    if not style then return end
    for _, key in ipairs(TAGOPS_STYLE_ADJUST_ORDER) do
        local value = tagopsStyleDefaultValue(style, TAGOPS_STYLE_ADJUST[key])
        if value and math.abs(value) > RHEA_ZERO_EPSILON then selected[key] = true end
    end
end

local function tagopsAutoAdjustSelected(subs, sel, styles)
    local selected = {}
    for _, i in ipairs(sel or {}) do
        local line = subs[i]
        if Rhea.isDialogue(line) then
            tagopsCollectAdjustKeysFromText(line.text or "", selected)
            tagopsCollectStyleAdjustKeys(line, styles, selected)
        end
    end
    return selected
end

local function tagopsResolveAdjustSelected(autoSelected, manualSelected)
    local selected = {}
    for key in pairs(autoSelected or {}) do selected[key] = true end
    for key, value in pairs(manualSelected or {}) do
        if value and TAGOPS_MANUAL_ADJUST_KEYS[key] then
            if selected[key] then
                selected[key] = nil
            else
                selected[key] = true
            end
        end
    end
    return selected
end

local function tagopsAdjustNeedsPerspectiveReproject(selected)
    for key in pairs(TAGOPS_PERSPECTIVE_REPROJECT_KEYS) do
        if selected and selected[key] then return true end
    end
    return false
end

local function tagopsTextHasLeadingName(text, names)
    local set = {}
    for _, name in ipairs(names or {}) do set[name] = true end
    text = tostring(text or "")
    local pos = 1
    while text:sub(pos, pos) == "{" do
        local close = text:find("}", pos + 1, true)
        if not close then break end
        local content = text:sub(pos + 1, close - 1)
        if content:sub(1, 1) ~= "*" then
            for _, tag in ipairs(RheaFoundation.parseTagBlock(content)) do
                if set[tag.name] then return true end
            end
        end
        pos = close + 1
    end
    return false
end

local function tagopsAdjustNumber(raw, amount, mode)
    local n = tonumber(raw)
    if not n then return raw end
    if mode == "Percent" then n = n * (1 + amount / 100) else n = n + amount end
    return Rhea.formatNum(n, 6)
end

local function tagopsAdjustToken(token, amount, mode)
    return (token:gsub("(" .. TAGOPS_NUM_VALUE_PATTERN .. ")", function(n)
        return tagopsAdjustNumber(n, amount, mode)
    end))
end

local function tagopsAdjustBlock(block, selected, amount, mode)
    local function frameFor(content, prefix, suffix)
        return {
            block = content,
            tags = RheaFoundation.parseTagBlock(content),
            index = 1,
            pos = 1,
            out = {},
            changed = 0,
            prefix = prefix or "",
            suffix = suffix or "",
        }
    end

    local stack = { frameFor(block) }
    while #stack > 0 do
        local frame = stack[#stack]
        local tag = frame.tags[frame.index]
        if not tag then
            frame.out[#frame.out + 1] = frame.block:sub(frame.pos)
            local adjusted = table.concat(frame.out)
            local changed = frame.changed
            table.remove(stack)
            if #stack == 0 then return adjusted, changed end
            local parent = stack[#stack]
            parent.out[#parent.out + 1] = frame.prefix .. adjusted .. frame.suffix
            parent.changed = parent.changed + changed
        else
            frame.out[#frame.out + 1] = frame.block:sub(frame.pos, tag.startPos - 1)
            frame.pos = tag.endPos + 1
            frame.index = frame.index + 1
            if tagopsTagSelected(tag.name, selected) then
                local adjusted = tagopsAdjustToken(tag.raw, amount, mode)
                frame.out[#frame.out + 1] = adjusted
                if adjusted ~= tag.raw then frame.changed = frame.changed + 1 end
            elseif tag.name == "t" then
                local tagStart = tag.raw:find("\\", 4, true)
                if not tagStart then
                    frame.out[#frame.out + 1] = tag.raw
                else
                    local tagEnd = tag.raw:sub(-1) == ")" and #tag.raw - 1 or #tag.raw
                    stack[#stack + 1] = frameFor(
                        tag.raw:sub(tagStart, tagEnd),
                        tag.raw:sub(1, tagStart - 1),
                        tag.raw:sub(tagEnd + 1)
                    )
                end
            else
                frame.out[#frame.out + 1] = tag.raw
            end
        end
    end
    return block, 0
end

local function tagopsAdjustText(text, selected, amount, mode)
    local out, pos, changed = {}, 1, 0
    for _, block in ipairs(RheaFoundation.iterTagBlocks(text)) do
        out[#out + 1] = text:sub(pos, block.openPos - 1)
        local nb, c = tagopsAdjustBlock(block.content, selected, amount, mode)
        if nb ~= "" then out[#out + 1] = "{" .. nb .. "}" end
        changed = changed + c
        pos = block.closePos + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), changed
end

local function tagopsInjectStyleAdjustments(text, selected, amount, mode, style)
    local payload = {}
    for _, key in ipairs(TAGOPS_STYLE_ADJUST_ORDER) do
        if selected[key] then
            local spec = TAGOPS_STYLE_ADJUST[key]
            local base = tagopsStyleDefaultValue(style, spec)
            local names = (TAGOPS_BY_KEY[key] and TAGOPS_BY_KEY[key].names) or { spec.tag }
            if base and not tagopsTextHasLeadingName(text, names) then
                local adjusted = tagopsAdjustNumber(tostring(base), amount, mode)
                local adjustedNumber = tonumber(adjusted)
                if adjustedNumber and math.abs(adjustedNumber - base) > RHEA_ZERO_EPSILON then
                    payload[#payload + 1] = "\\" .. spec.tag .. adjusted
                end
            end
        end
    end
    if #payload == 0 then return text, 0 end
    return tagopsAppendLeadingTags(text, table.concat(payload)), #payload
end

local function tagopsTransformKeyForName(name, selected)
    for _, key in ipairs(TAGOPS_NAME_TO_KEYS[name] or {}) do
        local def = TAGOPS_BY_KEY[key]
        if selected[key] and def and def.animatable then return key end
    end
    return nil
end

local function tagopsTransformText(text, selected, amount, style)
    local targets = {}
    for _, block in ipairs(RheaFoundation.iterTagBlocks(text)) do
        for _, tag in ipairs(RheaFoundation.parseTagBlock(block.content)) do
            if tag.name ~= "t" then
                local key = tagopsTransformKeyForName(tag.name, selected)
                if key and tostring(tag.value or ""):match(TAGOPS_NUM_VALUE_PATTERN) then
                    local adjusted = tagopsAdjustToken(tag.raw, amount, "Add")
                    if adjusted ~= tag.raw then targets[key] = adjusted end
                end
            end
        end
    end
    for _, key in ipairs(TAGOPS_STYLE_ADJUST_ORDER) do
        if selected[key] and not targets[key] then
            local spec = TAGOPS_STYLE_ADJUST[key]
            local base = tagopsStyleDefaultValue(style, spec)
            if base then
                local adjusted = tagopsAdjustNumber(tostring(base), amount, "Add")
                if tonumber(adjusted) and math.abs(tonumber(adjusted) - base) > RHEA_ZERO_EPSILON then
                    targets[key] = "\\" .. spec.tag .. adjusted
                end
            end
        end
    end
    local payload = {}
    for _, def in ipairs(TAGOPS_DEFS) do
        if targets[def.key] then payload[#payload + 1] = targets[def.key] end
    end
    if #payload == 0 then return text, 0 end
    return tagopsAppendLeadingTags(text, "\\t(" .. table.concat(payload) .. ")"), #payload
end

function TagOps.opAdjust(subs, sel, opts)
    if not sel or #sel == 0 then TagOps.U.alert(L("tagops_err_adjust_select")); return false end
    opts = opts or {}
    local amount = tonumber(opts.amount)
    if not amount then TagOps.U.alert(L("tagops_err_numeric")); return false end
    local styles = Rhea.styleMap(subs)
    local selected = tagopsResolveAdjustSelected(tagopsAutoAdjustSelected(subs, sel, styles), opts.selected)
    if not tagopsHasAnySelected(selected) then TagOps.U.alert(L("tagops_err_no_adjust_tags")); return false end
    local transformMode = opts.mode == "Transform"
    local perspectiveAware = not transformMode and tagopsAdjustNeedsPerspectiveReproject(selected)
    local perspectiveMeta, perspectiveStyles, perspectiveContextLoaded
    local function getPerspectiveContext()
        if not perspectiveContextLoaded then
            if RheaOps.Perspective.context then
                perspectiveMeta, perspectiveStyles = RheaOps.Perspective.context(subs)
            end
            perspectiveMeta = perspectiveMeta or {}
            perspectiveStyles = perspectiveStyles or styles
            perspectiveContextLoaded = true
        end
        return perspectiveMeta, perspectiveStyles
    end
    local linesChanged, tagsChanged = 0, 0
    for _, i in ipairs(sel) do
        local line = subs[i]
        local style = tagopsLineStyle(line, styles)
        local perspectiveQuad, perspectiveStyle, perspectiveMetaForLine, perspectiveStylesForLine
        if perspectiveAware
            and RheaOps.Perspective.isPerspectiveLine
            and RheaOps.Perspective.isPerspectiveLine(line) then
            perspectiveMetaForLine, perspectiveStylesForLine = getPerspectiveContext()
            perspectiveStyle = tagopsLineStyle(line, perspectiveStylesForLine) or style
            if perspectiveStyle and RheaOps.Perspective.captureQuad then
                perspectiveQuad = RheaOps.Perspective.captureQuad(line, perspectiveStyle, perspectiveMetaForLine, perspectiveStylesForLine)
            end
        end
        local nt, c
        if transformMode then
            nt, c = tagopsTransformText(line.text or "", selected, amount, style)
        else
            nt, c = tagopsAdjustText(line.text or "", selected, amount, opts.mode)
            local injected, injectedCount = tagopsInjectStyleAdjustments(nt, selected, amount, opts.mode, style)
            nt, c = injected, c + injectedCount
        end
        if c > 0 and nt ~= line.text then
            line.text = nt
            if perspectiveQuad and RheaOps.Perspective.reprojectLineToQuad then
                if RheaOps.Perspective.reprojectLineToQuad(line, perspectiveStyle,
                    perspectiveMetaForLine, perspectiveStylesForLine, perspectiveQuad, selected) then
                    c = c + 1
                end
            end
            subs[i] = line
            linesChanged = linesChanged + 1
            tagsChanged = tagsChanged + c
        end
    end
    if linesChanged == 0 then TagOps.U.alert(L("tagops_adjust_no_change")); return false end
    aegisub.set_undo_point("TagOps - Resize/Transform")
    if opts.info then
        TagOps.U.alert(string.format("%s: %d\n%s: %d", L("tagops_lines_changed"), linesChanged, L("tagops_tags_changed"), tagsChanged))
    end
    return true
end

local TAGOPS_NUM_PATTERN = "([%+%-]?%d*%.?%d+)"

local function tagopsCoord(n)
    return Rhea.formatNum(tonumber(n) or 0, 2)
end

local function tagopsShiftPair(x, y, dx, dy, scale)
    scale = scale or 1
    return tagopsCoord((tonumber(x) or 0) + dx * scale), tagopsCoord((tonumber(y) or 0) + dy * scale)
end

local function tagopsShiftPath(path, dx, dy, scale)
    return tostring(path or ""):gsub(TAGOPS_NUM_PATTERN .. "%s+" .. TAGOPS_NUM_PATTERN, function(x, y)
        local nx, ny = tagopsShiftPair(x, y, dx, dy, scale)
        return nx .. " " .. ny
    end)
end

local function tagopsFirstPos(text)
    local x, y = tostring(text or ""):match("\\pos%(%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*%)")
    if not x or not y then return nil, nil end
    return tonumber(x), tonumber(y)
end

local function tagopsFirstOrg(text)
    local x, y = tostring(text or ""):match("\\org%(%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*%)")
    if not x or not y then return nil, nil end
    return tonumber(x), tonumber(y)
end

local function tagopsPosAlignDelta(sourceLine, referenceLine, moveGeometry)
    if not (Rhea.isDialogue(sourceLine) and Rhea.isDialogue(referenceLine)) then
        return nil, nil, L("tagops_err_align_select")
    end
    local sourceX, sourceY = tagopsFirstPos(sourceLine.text)
    if not sourceX then return nil, nil, L("tagops_err_source_pos") end
    local referenceX, referenceY = tagopsFirstPos(referenceLine.text)
    if not referenceX then return nil, nil, L("tagops_err_reference_pos") end

    local dx, dy = sourceX - referenceX, sourceY - referenceY
    if dx == 0 and dy == 0 and moveGeometry then
        local sourceOrgX, sourceOrgY = tagopsFirstOrg(sourceLine.text)
        local referenceOrgX, referenceOrgY = tagopsFirstOrg(referenceLine.text)
        if sourceOrgX and referenceOrgX then
            dx, dy = sourceOrgX - referenceOrgX, sourceOrgY - referenceOrgY
        end
    end
    if dx == 0 and dy == 0 then return nil, nil, L("tagops_align_no_delta") end
    return dx, dy, nil
end

local function tagopsShiftAlignText(text, dx, dy, moveGeometry)
    text = tostring(text or "")
    text = text:gsub("\\pos%(%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*%)", function(x, y)
        local nx, ny = tagopsShiftPair(x, y, dx, dy)
        return "\\pos(" .. nx .. "," .. ny .. ")"
    end)
    if not moveGeometry then return text end

    text = text:gsub("\\move%(%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "(.-)%)", function(x1, y1, x2, y2, rest)
        local nx1, ny1 = tagopsShiftPair(x1, y1, dx, dy)
        local nx2, ny2 = tagopsShiftPair(x2, y2, dx, dy)
        return "\\move(" .. nx1 .. "," .. ny1 .. "," .. nx2 .. "," .. ny2 .. rest .. ")"
    end)
    text = text:gsub("\\org%(%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*%)", function(x, y)
        local nx, ny = tagopsShiftPair(x, y, dx, dy)
        return "\\org(" .. nx .. "," .. ny .. ")"
    end)
    text = text:gsub("(\\i?clip)%(%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*,%s*" .. TAGOPS_NUM_PATTERN .. "%s*%)", function(tag, x1, y1, x2, y2)
        local nx1, ny1 = tagopsShiftPair(x1, y1, dx, dy)
        local nx2, ny2 = tagopsShiftPair(x2, y2, dx, dy)
        return tag .. "(" .. nx1 .. "," .. ny1 .. "," .. nx2 .. "," .. ny2 .. ")"
    end)
    text = text:gsub("(\\i?clip)%(%s*(%d+)%s*,%s*m%s+([^%)]+)%)", function(tag, scaleText, path)
        local factor = 2 ^ ((tonumber(scaleText) or 1) - 1)
        return tag .. "(" .. scaleText .. ",m " .. tagopsShiftPath(path, dx, dy, factor) .. ")"
    end)
    text = text:gsub("(\\i?clip)%(%s*m%s+([^%)]+)%)", function(tag, path)
        return tag .. "(m " .. tagopsShiftPath(path, dx, dy) .. ")"
    end)

    local draw = text:match("}m%s+([^{]+)")
    if draw then
        local nextDraw = tagopsShiftPath(draw, dx, dy)
        if nextDraw ~= draw then
            text = text:gsub("}m%s+" .. Rhea.escapePattern(draw), "}m " .. nextDraw, 1)
        end
    end
    return text
end

function TagOps.opPosAlign(subs, sel, opts)
    local indices = RheaFoundation.selectionDialogueIndices(subs, sel)
    if #indices < 2 then TagOps.U.alert(L("tagops_err_align_select")); return false end
    local moveGeometry = opts and opts.align_org == "Move org"
    local sourceIndex, referenceIndex = indices[1], indices[2]
    local dx, dy, err = tagopsPosAlignDelta(subs[sourceIndex], subs[referenceIndex], moveGeometry)
    if err then TagOps.U.alert(err); return false end

    local changed = 0
    for _, i in ipairs(indices) do
        if i ~= sourceIndex then
            local line = subs[i]
            local nextText = tagopsShiftAlignText(line.text or "", dx, dy, moveGeometry)
            if nextText ~= line.text then
                line.text = nextText
                subs[i] = line
                changed = changed + 1
            end
        end
    end
    if changed == 0 then TagOps.U.alert(L("tagops_align_no_delta")); return false end
    aegisub.set_undo_point("TagOps - Pos Align")
    if opts and opts.info then TagOps.U.alert(string.format(L("tagops_align_done"), changed)) end
    return changed > 0
end

TagOps.defs = TAGOPS_DEFS
TagOps.actions = {"Resize / transform", "Pos Align"}

local function tagopsNormalizeAction(action)
    action = tostring(action or "")
    if action == "Adjust tags" or action == "Copy tags" or action == "Copy Tags" then return "Resize / transform" end
    if action == "" then return "" end
    return RheaFoundation.choose(action, TagOps.actions, "Resize / transform")
end


local HELP_TEXTS = {
en = [[
RHEA SIGNS - USER GUIDE

Main panel:
Mask and Perspective are on the top row; Shapes and Sign are below them.
Each module has an Action field. Leave Action empty to skip that module.

Mask:
Apply Mask, Create Layer, Replace Mask, Save Shape, Delete Shape, and Clean DR.
The built-in square, rounded, circle, and triangle masks are centered around
their own origin, so they behave predictably with the line position.

Perspective:
Copies, remaps, scales quads, bakes, restores, or reprojects perspective tags.
Map controls corner order. Org controls the destination origin. X, Y, and Quad
drive the scale operations.

Sign:
Typewriter reveals characters. Vertical Drop distributes text vertically; Y
spacing adjusts the distance between generated elements and accepts negatives.
Circle Text creates character lines on a circle. Curve Text places character
lines along a vector clip. Clean SiO removes Sign output.

Shapes:
Unify Positions gives selected ASS drawings one shared pivot without moving
their rendered geometry. Place on Perimeter repeats multilayer units along all
visible exterior contours, with an optional mode for real nonzero-winding holes.
Shape Color Optimizer merges nearby colors or reduces reliable gradients. Its
mode, intensity, OKLab threshold, band limit, and summary option are editable in
the main panel and saved in Config.

Auxiliary buttons:
Signs Editor edits repeated sign text in bulk. FastSigns creates box, glow, and
front text layers. TagOps handles tag copy, keep-only, numeric recalculation,
untimed transforms, and position alignment. Config stores language, mask color,
FastSigns settings, and the Shapes controls.

Toolbox:
Font and Style Manager replaces fonts in styles and optional \fn tags,
batch-edits style fields and colors, clones styles, and
refreshes the detected font and style lists. In Fast Fades, In sets fade-in from
the current video frame, Out sets fade-out, and Clean removes internal fade edges at
exact shared timing boundaries between selected groups. Fade-in and fade-out
preserve the other duration and unrelated tags.
Shuffle Line Text redistributes text among selected dialogue rows without moving
their timing or metadata. Leave the dropdown empty to skip it.

Generated markers:
DR = Masks, SiO = Sign, FS = FastSigns.
]],
es = [[
RHEA SIGNS - GUIA DE USO

Panel principal:
Mask y Perspective estan arriba; Shapes y Sign estan debajo. Cada modulo tiene
un campo Accion. Deja Accion vacia para omitir ese modulo.

Mask:
Apply Mask, Create Layer, Replace Mask, Save Shape, Delete Shape y Clean DR.
Las mascaras internas square, rounded, circle y triangle estan centradas sobre
su propio origen para comportarse de forma predecible con la posicion de linea.

Perspective:
Copia, remapea, escala quads, guarda, restaura o reproyecta tags de perspectiva.
Map controla el orden de esquinas. Org controla el origen destino. X, Y y Quad
controlan las operaciones de escala.

Sign:
Typewriter revela caracteres. Vertical Drop distribuye texto en vertical;
Espacio Y ajusta la distancia entre elementos y acepta valores negativos.
Circle Text genera lineas por caracter en circulo. Curve Text coloca lineas por
caracter sobre un clip vectorial. Clean SiO elimina la salida de Sign.

Shapes:
Unificar posiciones da a los dibujos ASS seleccionados un pivote compartido sin
mover su geometria renderizada. Pegar al perimetro repite unidades multicapa por
todos los contornos exteriores visibles, con un modo opcional para huecos reales
segun nonzero winding. Optimizar color de shapes fusiona colores cercanos o
reduce gradientes fiables. Modo, intensidad, umbral OKLab, limite de bandas y
resumen se editan en el panel principal y se guardan en Config.

Botones auxiliares:
Editor de carteles edita texto repetido en lote. FastSigns crea capas de caja,
glow y texto frontal. TagOps maneja copiar tags, Keep Only, recalculo numerico,
transformaciones sin tiempos y alineacion de posicion. Config guarda idioma,
color de mascara, ajustes de FastSigns y controles de Shapes.

Herramientas:
El gestor de fuentes y estilos cambia fuentes en estilos y tags \fn opcionales,
edita campos y colores en lote, clona
estilos y actualiza las listas detectadas. En Fast Fades, Entrada fija la entrada
desde el frame actual, Salida fija la salida y Limpiar elimina los bordes internos del
limite temporal exacto entre grupos seleccionados. La entrada y la salida no
alteran la otra duracion ni los demas tags. Mezclar
texto de lineas redistribuye el texto sin mover tiempos ni metadatos. Deja el
dropdown vacio para omitirlo.

Marcadores generados:
DR = Mascaras, SiO = Sign, FS = FastSigns.
]],
pt = [[
RHEA SIGNS - GUIA DE USO

Painel principal:
Mask e Perspective ficam acima; Formas e Sign ficam abaixo. Cada modulo tem um
campo Acao. Deixe Acao vazio para ignorar esse modulo.

Mask:
Apply Mask, Create Layer, Replace Mask, Save Shape, Delete Shape e Clean DR.
As mascaras internas square, rounded, circle e triangle ficam centradas no
proprio origem para agir de forma previsivel com a posicao da linha.

Perspective:
Copia, remapeia, escala quads, grava, restaura ou reprojeta tags de perspectiva.
Map controla a ordem dos cantos. Org controla a origem de destino. X, Y e Quad
controlam as operacoes de escala.

Sign:
Typewriter revela caracteres. Vertical Drop distribui texto na vertical; Espaço
Y ajusta a distância entre elementos e aceita valores negativos.
Circle Text gera linhas por caractere em circulo. Curve Text coloca linhas por
caractere sobre um clip vetorial. Clean SiO remove a saida de Sign.

Formas:
Unificar posicoes fornece aos desenhos ASS selecionados um pivo compartilhado
sem mover a geometria renderizada. Colocar no perimetro repete unidades em
camadas por todos os contornos exteriores visiveis, com um modo opcional para
furos reais segundo nonzero winding. Otimizar cores combina cores proximas ou
reduz gradientes confiaveis. Modo, intensidade, limiar OKLab, limite de faixas e
resumo sao editados no painel principal e salvos em Config.

Botoes auxiliares:
Editor de placas edita texto repetido em lote. FastSigns cria camadas de caixa,
glow e texto frontal. TagOps cuida de copiar tags, Keep Only, recalculo numerico,
transformacoes sem tempos e alinhamento de posicao. Config guarda idioma, cor da
mascara, ajustes de FastSigns e controles de Formas.

Ferramentas:
O gerenciador de fontes e estilos troca fontes em estilos e etiquetas \fn
opcionais, edita campos e cores em lote, clona estilos
e atualiza as listas detectadas. Em Fast Fades, Entrada define a entrada desde o
frame atual, Saida define a saida e Limpar remove as bordas internas no limite de tempo
exato entre grupos selecionados. A entrada e a saida nao alteram a outra duracao
nem as demais tags. Embaralhar texto das
linhas redistribui o texto sem mover tempos nem metadados. Deixe o dropdown vazio
para ignora-lo.

Marcadores gerados:
DR = Mascaras, SiO = Sign, FS = FastSigns.
]],
}
local function helpText()
    return HELP_TEXTS[current_lang] or HELP_TEXTS.en
end

local CHOICE_KEYS = {
    ["en"] = "lang_en", ["es"] = "lang_es", ["pt"] = "lang_pt",
    ["Apply Mask"] = "op_apply_mask", ["Create Layer"] = "op_create_layer",
    ["Replace Mask"] = "op_replace_mask", ["Save Shape"] = "op_save_shape", ["Delete Shape"] = "op_delete_shape", ["Clean DR"] = "op_clean_dr",
    ["Typewriter"] = "op_typewriter", ["Vertical Drop"] = "op_vertical_drop", ["Circle Text"] = "op_circle_text", ["Curve Text"] = "op_curve_text",
    ["Clean SiO"] = "op_clean_sio", ["Frame"] = "choice_frame", ["Duration"] = "choice_duration", ["Normal"] = "choice_normal",
    ["Invertido"] = "choice_inverted", ["Vertical"] = "choice_vertical", ["from clip"] = "choice_from_clip",
    ["Copy Exact (same plane)"] = "pk_copy_exact", ["Copy Static Plane (keep \\pos)"] = "pk_copy_static", ["Copy Move Plane (whole plane)"] = "pk_copy_move_plane",
    ["Copy w/ corner swap"] = "pk_copy_swap", ["Copy Translate (keep \\pos)"] = "pk_copy_translate", ["Copy Transport (\\org -> \\pos)"] = "pk_copy_transport",
    ["Mass FSC (lock quad)"] = "pk_mass_fsc", ["Scale Quad (3D Box)"] = "pk_scale_quad",
    ["Bake Extradata"] = "pk_bake_extra", ["Restore Extradata"] = "pk_restore_extra",
    ["Identity reproject"] = "pk_identity", ["ABCD (exact copy)"] = "map_abcd", ["BADC (h-mirror)"] = "map_badc",
    ["DCBA (v-mirror)"] = "map_dcba", ["CDAB (rot 180)"] = "map_cdab", ["BCDA (rot 90 CW)"] = "map_bcda",
    ["DABC (rot 90 CCW)"] = "map_dabc", ["ABDC (swap CD)"] = "map_abdc", ["BACD (swap AB)"] = "map_bacd",
    ["AB src + CD dst"] = "map_ab_cd", ["CD src + AB dst"] = "map_cd_ab", ["AC src + BD dst"] = "map_ac_bd",
    ["BD src + AC dst"] = "map_bd_ac", ["1 keep dst org"] = "org_keep", ["2 quad center"] = "org_center", ["3 minimize fax"] = "org_min_fax",
    ["Resize / transform"] = "tagops_adjust", ["Adjust tags"] = "tagops_adjust",
    ["Pos Align"] = "tagops_pos_align",
    ["Add"] = "tagops_add", ["Percent"] = "tagops_percent", ["Transform"] = "tagops_transform",
    ["Keep org"] = "tagops_keep_org", ["Move org"] = "tagops_move_org",
    ["Unify Positions"] = "sh_action_unify",
    ["Place on Perimeter"] = "sh_action_perimeter",
    ["Shape Color Optimizer"] = "sh_action_optimizer",
    ["Exterior contours only"] = "sh_perimeter_exterior",
    ["Exterior contours and holes"] = "sh_perimeter_holes",
    ["Auto"] = "sh_mode_auto",
    ["Similar colors"] = "sh_mode_similar",
    ["Full gradient"] = "sh_mode_gradient",
    ["Balanced"] = "sh_intensity_balanced",
    ["Fidelity"] = "sh_intensity_fidelity",
    ["Aggressive"] = "sh_intensity_aggressive",
    ["Font and Style Manager"] = "tool_font_manager",
    ["Fast Fades"] = "tool_fade_suite",
    ["Shuffle Line Text"] = "tool_shuffle_line_text",
}

local function choiceLabel(raw)
    local key = CHOICE_KEYS[raw]
    if key then
        local translated = L(key)
        if translated ~= key then return translated end
    end
    return tostring(raw or "")
end

local function dropdownData(items)
    local out, toRaw, toShown = {""}, {[""] = ""}, {[""] = ""}
    local n = 1
    for _, raw in ipairs(items or {}) do
        if raw ~= nil and raw ~= "" then
            local shown = string.format("%d. %s", n, choiceLabel(raw))
            out[#out + 1] = shown
            toRaw[shown] = raw
            toRaw[raw] = raw
            toShown[raw] = shown
            n = n + 1
        end
    end
    return out, toRaw, toShown
end

local function shownChoice(toShown, raw)
    return (toShown and toShown[raw]) or raw or ""
end

local function rawChoice(toRaw, shown)
    return (toRaw and toRaw[shown]) or shown or ""
end

local INTEGRATED_TOOL_SOURCES = {
    ["Shapes"] = [====[
local SharedShapeOptimizer = require("kite.ShapeOptimizer")
local Unify = (function()
local script_name = "Unify Shape Positions"
local script_description = "Unifies ASS drawing pivots without changing visible placement"
local script_author = "Kiter"
local script_version = "1.0.0"
local ShapeCore = assert(RheaFoundation and RheaFoundation.Shapes)
local EPSILON = ShapeCore.epsilon
local current_context = nil
local tr
tr = function(key, fallback, ...)
  return ShapeCore.translate(current_context, key, fallback, ...)
end
local set_context
set_context = function(context)
  current_context = context or { }
end
local finite = ShapeCore.finite
local format_number = ShapeCore.formatNumber
local copy_line = Rhea.cloneLine
local split_shape_text
split_shape_text = function(text)
  return ShapeCore.splitText(text, tr, "The drawing needs leading tags, including \\pos and \\pN.")
end
local has_plain_tag = ShapeCore.hasPlainTag
local last_numeric_tag = ShapeCore.lastNumericTag
local parse_position
parse_position = function(prefix)
  return ShapeCore.parsePosition(prefix, tr, "Each line must have exactly one leading \\pos(x,y).")
end
local tokenize_path
tokenize_path = function(path)
  return ShapeCore.tokenizePath(path, tr)
end
local validate_path_tokens
validate_path_tokens = function(tokens)
  local command, count = nil, 0
  local valid_group
  valid_group = function()
    if not (command) then
      return true
    end
    if command == "c" then
      return count == 0
    end
    if command == "b" then
      return count >= 6 and count % 6 == 0
    end
    if command == "s" then
      return count >= 6 and count % 2 == 0
    end
    return count >= 2 and count % 2 == 0
  end
  for _index_0 = 1, #tokens do
    local token = tokens[_index_0]
    if token.kind == "command" then
      if not (valid_group()) then
        return false
      end
      command, count = token.value, 0
    else
      if not (command) then
        return false
      end
      count = count + 1
    end
  end
  return valid_group()
end
local map_path
map_path = function(path, map_x, map_y)
  local tokens, err = tokenize_path(path)
  if not (tokens) then
    return nil, err
  end
  if not (validate_path_tokens(tokens)) then
    return nil, tr("sh_err_coordinates", "The drawing has an invalid coordinate count.")
  end
  local output, coordinate = { }, 0
  for _index_0 = 1, #tokens do
    local token = tokens[_index_0]
    if token.kind == "command" then
      output[#output + 1] = token.value
      coordinate = 0
    else
      coordinate = coordinate + 1
      local mapper
      if coordinate % 2 == 1 then
        mapper = map_x
      else
        mapper = map_y
      end
      output[#output + 1] = format_number(mapper(token.value))
    end
  end
  return table.concat(output, " ")
end
local shift_path
shift_path = function(path, dx, dy)
  return map_path(path, (function(value)
    return value + dx
  end), (function(value)
    return value + dy
  end))
end
local round_fixed
round_fixed = function(value)
  return math.floor(value * 64 + 0.5)
end
local rebase_path
rebase_path = function(prepared, pivot)
  local factor = 2 ^ (prepared.drawing_scale - 1)
  local screen_scale_x = prepared.scale_x / (100 * factor)
  local screen_scale_y = prepared.scale_y / (100 * factor)
  local delta_x = round_fixed(prepared.position.x) - round_fixed(pivot.x)
  local delta_y = round_fixed(prepared.position.y) - round_fixed(pivot.y)
  local map_x
  map_x = function(value)
    return (round_fixed(value * screen_scale_x) + delta_x) / (64 * screen_scale_x)
  end
  local map_y
  map_y = function(value)
    return (round_fixed(value * screen_scale_y) + delta_y) / (64 * screen_scale_y)
  end
  return map_path(prepared.drawing, map_x, map_y)
end
local prepare_text
prepare_text = function(text, style)
  if style == nil then
    style = { }
  end
  local parts, err = split_shape_text(text)
  if not (parts) then
    return nil, err
  end
  local prefix = parts.prefix
  local _list_0 = {
    "move",
    "org",
    "clip",
    "iclip",
    "t",
    "fr",
    "fax",
    "fay",
    "r"
  }
  for _index_0 = 1, #_list_0 do
    local tag = _list_0[_index_0]
    if has_plain_tag(prefix, tag) then
      return nil, tr("sh_unify_err_tag", "\\%s is not supported because the compensation would not have one static pivot.", tag)
    end
  end
  local position, pos_err = parse_position(prefix)
  if not (position) then
    return nil, pos_err
  end
  local drawing_scale = last_numeric_tag(prefix, "p")
  if not (drawing_scale and drawing_scale == math.floor(drawing_scale) and drawing_scale >= 1 and drawing_scale <= 10) then
    return nil, tr("sh_err_drawing_scale", "Drawing mode must be \\p1 or higher.")
  end
  local style_angle = finite(style.angle) or 0
  if math.abs(style_angle) >= EPSILON then
    return nil, tr("sh_unify_err_style_rotation", "The style has rotation; use an unrotated drawing first.")
  end
  local scale_x = last_numeric_tag(prefix, "fscx") or finite(style.scale_x) or 100
  local scale_y = last_numeric_tag(prefix, "fscy") or finite(style.scale_y) or 100
  if not (scale_x > 0 and scale_y > 0) then
    return nil, tr("sh_err_positive_scale", "\\fscx and \\fscy must be greater than zero.")
  end
  local tokens, token_err = tokenize_path(parts.drawing)
  if not (tokens) then
    return nil, token_err
  end
  if not (validate_path_tokens(tokens)) then
    return nil, tr("sh_err_coordinates", "The drawing has an invalid coordinate count.")
  end
  return {
    text = tostring(text),
    prefix = prefix,
    drawing = parts.drawing,
    suffix = parts.suffix,
    position = position,
    drawing_scale = drawing_scale,
    scale_x = scale_x,
    scale_y = scale_y
  }
end
local replace_position
replace_position = function(prefix, position, pattern)
  local replacement = "\\pos(" .. tostring(format_number(position.x)) .. "," .. tostring(format_number(position.y)) .. ")"
  local mapped, count = prefix:gsub(pattern, replacement)
  if not (count == 1) then
    return nil, tr("sh_unify_err_replace_pos", "The line's \\pos could not be replaced.")
  end
  return mapped
end
local unify_prepared
unify_prepared = function(prepared, pivot)
  local factor = 2 ^ (prepared.drawing_scale - 1)
  local dx = (prepared.position.x - pivot.x) * factor * 100 / prepared.scale_x
  local dy = (prepared.position.y - pivot.y) * factor * 100 / prepared.scale_y
  local drawing = prepared.drawing
  if math.abs(dx) >= EPSILON or math.abs(dy) >= EPSILON then
    local err
    drawing, err = rebase_path(prepared, pivot)
    if not (drawing) then
      return nil, err
    end
  end
  local prefix, err = replace_position(prepared.prefix, pivot, prepared.position.pattern)
  if not (prefix) then
    return nil, err
  end
  return prefix .. drawing .. prepared.suffix
end
local style_map = ShapeCore.styleMaps
local selection_indices = ShapeCore.selectionIndices
local unify_selection
unify_selection = function(subs, sel, active_line)
  local indices = selection_indices(subs, sel)
  if #indices < 2 then
    return nil, tr("sh_unify_err_selection", "Select at least two drawing lines.")
  end
  local styles, styles_folded = style_map(subs)
  local prepared = { }
  for _index_0 = 1, #indices do
    local index = indices[_index_0]
    local line = subs[index]
    local style_name = tostring(line.style or "")
    local style = ShapeCore.styleFor(styles, styles_folded, style_name)
    if not (style) then
      return nil, tr("sh_err_style", "Line %d: style '%s' was not found.", index, style_name)
    end
    local data, err = prepare_text(line.text, style)
    if not (data) then
      return nil, tr("sh_err_line", "Line %d: %s", index, err)
    end
    prepared[#prepared + 1] = {
      index = index,
      line = line,
      data = data
    }
  end
  local reference = prepared[1]
  active_line = tonumber(active_line)
  if active_line then
    for _index_0 = 1, #prepared do
      local item = prepared[_index_0]
      if item.index == active_line then
        reference = item
        break
      end
    end
  end
  local pivot = {
    x = reference.data.position.x,
    y = reference.data.position.y
  }
  local updates = { }
  for _index_0 = 1, #prepared do
    local item = prepared[_index_0]
    local new_text, err = unify_prepared(item.data, pivot)
    if not (new_text) then
      return nil, tr("sh_err_line", "Line %d: %s", item.index, err)
    end
    local line = copy_line(item.line)
    line.text = new_text
    updates[#updates + 1] = {
      index = item.index,
      line = line
    }
  end
  for _index_0 = 1, #updates do
    local update = updates[_index_0]
    subs[update.index] = update.line
  end
  return {
    selection = sel,
    pivot = pivot,
    count = #updates
  }
end
local main
main = function(subs, sel, active_line, context)
  set_context(context)
  local result, err = unify_selection(subs, sel, active_line)
  if not (result) then
    return sel, false, err
  end
  if context and context.undo then
    context.undo("sh_undo_unify", "Rhea Signs: unify shape positions")
  elseif aegisub and aegisub.set_undo_point then
    aegisub.set_undo_point(script_name)
  end
  return result.selection, true, result
end
return {
  name = script_name,
  description = script_description,
  version = script_version,
  set_context = set_context,
  prepare_text = prepare_text,
  shift_path = shift_path,
  unify_prepared = unify_prepared,
  unify_selection = unify_selection,
  main = main
}
end)()
local Perimeter = (function()
local script_name = "Place Shapes on Perimeter"
local script_description = "Repeats multilayer units along the true contour of an ASS drawing"
local script_author = "Kiter"
local script_version = "1.3.0"
local ShapeCore = assert(RheaFoundation and RheaFoundation.Shapes)
local EPSILON = ShapeCore.epsilon
local CURVE_TOLERANCE = 0.01
local MAX_CURVE_DEPTH = 18
local MAX_OUTPUT_LINES = 4000
local CORNER_EPSILON = 0.00001
local MAX_CUSTOM_PERIOD = 16
local current_context = nil
local tr
tr = function(key, fallback, ...)
  return ShapeCore.translate(current_context, key, fallback, ...)
end
local set_context
set_context = function(context)
  current_context = context or { }
end
local finite = ShapeCore.finite
local format_number = ShapeCore.formatNumber
local copy_line = Rhea.cloneLine
local point
point = function(x, y)
  return {
    x = x,
    y = y
  }
end
local same_point
same_point = function(a, b, epsilon)
  if epsilon == nil then
    epsilon = EPSILON
  end
  return a and b and math.abs(a.x - b.x) <= epsilon and math.abs(a.y - b.y) <= epsilon
end
local distance
distance = function(a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  return math.sqrt(dx * dx + dy * dy)
end
local normalize
normalize = function(x, y)
  local length = math.sqrt(x * x + y * y)
  if not (length > EPSILON) then
    return nil
  end
  return {
    x = x / length,
    y = y / length
  }
end
local atan2 = RheaFoundation.atan2
local split_shape_text
split_shape_text = function(text)
  return ShapeCore.splitText(text, tr, "The drawing needs leading tags with \\pos and \\pN.")
end
local has_plain_tag = ShapeCore.hasPlainTag
local last_numeric_tag = ShapeCore.lastNumericTag
local parse_position
parse_position = function(prefix)
  return ShapeCore.parsePosition(prefix, tr)
end
local tokenize_path
tokenize_path = function(path)
  return ShapeCore.tokenizePath(path, tr)
end
local command_groups
command_groups = function(tokens)
  local groups, current = { }, nil
  for _index_0 = 1, #tokens do
    local token = tokens[_index_0]
    if token.kind == "command" then
      current = {
        command = token.value,
        values = { }
      }
      groups[#groups + 1] = current
    else
      if not (current) then
        return nil, tr("sh_perimeter_err_before_command", "Coordinates appear before the first drawing command.")
      end
      current.values[#current.values + 1] = token.value
    end
  end
  return groups
end
local line_segment
line_segment = function(a, b)
  return {
    kind = "line",
    p0 = a,
    p1 = b
  }
end
local cubic_segment
cubic_segment = function(a, b, c, d)
  return {
    kind = "cubic",
    p0 = a,
    p1 = b,
    p2 = c,
    p3 = d
  }
end
local parse_contours
parse_contours = function(path)
  local tokens, token_err = tokenize_path(path)
  if not (tokens) then
    return nil, token_err
  end
  local groups, group_err = command_groups(tokens)
  if not (groups) then
    return nil, group_err
  end
  local contours, current, current_point = { }, nil, nil
  local finish_contour
  finish_contour = function()
    if not (current) then
      return
    end
    if current.closed and current_point and not same_point(current_point, current.start) then
      current.segments[#current.segments + 1] = line_segment(current_point, current.start)
    end
    contours[#contours + 1] = current
    current, current_point = nil, nil
  end
  for _index_0 = 1, #groups do
    local group = groups[_index_0]
    local command, values = group.command, group.values
    if command == "m" or command == "n" then
      if not (#values == 2) then
        return nil, tr("sh_perimeter_err_move_pair", "Each %s command must contain exactly one coordinate pair.", command)
      end
      finish_contour()
      current_point = point(values[1], values[2])
      current = {
        start = current_point,
        segments = { },
        closed = command == "m"
      }
    elseif command == "l" then
      if not (current and current_point) then
        return nil, tr("sh_perimeter_err_line_start", "An l command appears before the initial m command.")
      end
      if not (#values >= 2 and #values % 2 == 0) then
        return nil, tr("sh_perimeter_err_line_pairs", "The l command requires coordinate pairs.")
      end
      for index = 1, #values, 2 do
        local next_point = point(values[index], values[index + 1])
        if not (same_point(current_point, next_point)) then
          current.segments[#current.segments + 1] = line_segment(current_point, next_point)
        end
        current_point = next_point
      end
    elseif command == "b" then
      if not (current and current_point) then
        return nil, tr("sh_perimeter_err_bezier_start", "A b command appears before the initial m command.")
      end
      if not (#values >= 6 and #values % 6 == 0) then
        return nil, tr("sh_perimeter_err_bezier_groups", "The b command requires groups of six coordinates.")
      end
      for index = 1, #values, 6 do
        local control_a = point(values[index], values[index + 1])
        local control_b = point(values[index + 2], values[index + 3])
        local next_point = point(values[index + 4], values[index + 5])
        current.segments[#current.segments + 1] = cubic_segment(current_point, control_a, control_b, next_point)
        current_point = next_point
      end
    else
      return nil, tr("sh_perimeter_err_spline", "Spline commands s/p/c must first be converted to lines or b Beziers.")
    end
  end
  finish_contour()
  if #contours == 0 then
    return nil, tr("sh_perimeter_err_no_contour", "No valid contour was found.")
  end
  return contours
end
local new_bounds
new_bounds = function()
  return {
    l = math.huge,
    t = math.huge,
    r = -math.huge,
    b = -math.huge
  }
end
local include_point
include_point = function(bounds, p)
  bounds.l = math.min(bounds.l, p.x)
  bounds.t = math.min(bounds.t, p.y)
  bounds.r = math.max(bounds.r, p.x)
  bounds.b = math.max(bounds.b, p.y)
end
local cubic_point
cubic_point = function(segment, t)
  return RheaFoundation.bezierPoint(t, segment.p0, segment.p1, segment.p2, segment.p3)
end
local cubic_derivative
cubic_derivative = function(segment, t)
  return RheaFoundation.bezierDerivative(t, segment.p0, segment.p1, segment.p2, segment.p3)
end
local quadratic_roots
quadratic_roots = function(a, b, c)
  local roots = { }
  if math.abs(a) < EPSILON then
    if math.abs(b) >= EPSILON then
      roots[1] = -c / b
    end
    return roots
  end
  local discriminant = b * b - 4 * a * c
  if discriminant < 0 then
    return roots
  end
  local root = math.sqrt(math.max(0, discriminant))
  roots[#roots + 1] = (-b - root) / (2 * a)
  if root > EPSILON then
    roots[#roots + 1] = (-b + root) / (2 * a)
  end
  return roots
end
local cubic_extrema
cubic_extrema = function(p0, p1, p2, p3)
  local a = -p0 + 3 * p1 - 3 * p2 + p3
  local b = 3 * p0 - 6 * p1 + 3 * p2
  local c = -3 * p0 + 3 * p1
  return quadratic_roots(3 * a, 2 * b, c)
end
local include_segment_bounds
include_segment_bounds = function(bounds, segment)
  include_point(bounds, segment.p0)
  if segment.kind == "line" then
    include_point(bounds, segment.p1)
    return
  end
  include_point(bounds, segment.p3)
  local _list_0 = cubic_extrema(segment.p0.x, segment.p1.x, segment.p2.x, segment.p3.x)
  for _index_0 = 1, #_list_0 do
    local t = _list_0[_index_0]
    if t > EPSILON and t < 1 - EPSILON then
      include_point(bounds, cubic_point(segment, t))
    end
  end
  local _list_1 = cubic_extrema(segment.p0.y, segment.p1.y, segment.p2.y, segment.p3.y)
  for _index_0 = 1, #_list_1 do
    local t = _list_1[_index_0]
    if t > EPSILON and t < 1 - EPSILON then
      include_point(bounds, cubic_point(segment, t))
    end
  end
end
local path_bounds
path_bounds = function(contours)
  local bounds = new_bounds()
  for _index_0 = 1, #contours do
    local contour = contours[_index_0]
    local _list_0 = contour.segments
    for _index_1 = 1, #_list_0 do
      local segment = _list_0[_index_1]
      include_segment_bounds(bounds, segment)
    end
  end
  if bounds.l == math.huge then
    return nil
  end
  bounds.width = bounds.r - bounds.l
  bounds.height = bounds.b - bounds.t
  return bounds
end
local alignment_factors
alignment_factors = function(alignment)
  alignment = tonumber(alignment)
  if not (alignment and alignment >= 1 and alignment <= 9) then
    return nil
  end
  local ax
  if alignment == 1 or alignment == 4 or alignment == 7 then
    ax = 0
  elseif alignment == 2 or alignment == 5 or alignment == 8 then
    ax = 0.5
  else
    ax = 1
  end
  local ay
  if alignment >= 7 then
    ay = 0
  elseif alignment >= 4 then
    ay = 0.5
  else
    ay = 1
  end
  return ax, ay
end
local transform_segment
transform_segment = function(segment, transform)
  local map
  map = function(p)
    return point(transform.ox + p.x * transform.sx, transform.oy + p.y * transform.sy)
  end
  if segment.kind == "line" then
    return line_segment(map(segment.p0), map(segment.p1))
  else
    return cubic_segment(map(segment.p0), map(segment.p1), map(segment.p2), map(segment.p3))
  end
end
local transform_contours
transform_contours = function(contours, transform)
  local output = { }
  for _index_0 = 1, #contours do
    local contour = contours[_index_0]
    local mapped = {
      start = point(transform.ox + contour.start.x * transform.sx, transform.oy + contour.start.y * transform.sy),
      closed = contour.closed,
      segments = { }
    }
    local _list_0 = contour.segments
    for _index_1 = 1, #_list_0 do
      local segment = _list_0[_index_1]
      mapped.segments[#mapped.segments + 1] = transform_segment(segment, transform)
    end
    output[#output + 1] = mapped
  end
  return output
end
local prepare_shape
prepare_shape = function(text, style)
  if style == nil then
    style = { }
  end
  local parts, parts_err = split_shape_text(text)
  if not (parts) then
    return nil, parts_err
  end
  local prefix = parts.prefix
  local _list_0 = {
    "move",
    "org",
    "clip",
    "iclip",
    "t",
    "fr",
    "fax",
    "fay",
    "r",
    "pbo"
  }
  for _index_0 = 1, #_list_0 do
    local tag = _list_0[_index_0]
    if has_plain_tag(prefix, tag) then
      return nil, tr("sh_perimeter_err_tag", "\\%s is not supported in input geometry.", tag)
    end
  end
  local position, pos_err = parse_position(prefix)
  if not (position) then
    return nil, pos_err
  end
  local drawing_scale = last_numeric_tag(prefix, "p")
  if not (drawing_scale and drawing_scale == math.floor(drawing_scale) and drawing_scale >= 1 and drawing_scale <= 10) then
    return nil, tr("sh_err_drawing_scale", "Drawing mode must be \\p1 or higher.")
  end
  local scale_x = last_numeric_tag(prefix, "fscx") or finite(style.scale_x) or 100
  local scale_y = last_numeric_tag(prefix, "fscy") or finite(style.scale_y) or 100
  if not (scale_x > 0 and scale_y > 0) then
    return nil, tr("sh_err_positive_scale", "\\fscx and \\fscy must be greater than zero.")
  end
  if math.abs(finite(style.angle) or 0) >= EPSILON then
    return nil, tr("sh_perimeter_err_style_rotation", "The style has rotation; use unrotated geometry.")
  end
  local alignment = last_numeric_tag(prefix, "an") or finite(style.align)
  local ax, ay = alignment_factors(alignment)
  if not (ax and ay) then
    return nil, tr("sh_perimeter_err_alignment", "An effective \\an1..\\an9 could not be determined.")
  end
  local contours, contour_err = parse_contours(parts.drawing)
  if not (contours) then
    return nil, contour_err
  end
  local raw_bounds = path_bounds(contours)
  if not (raw_bounds and raw_bounds.width > EPSILON and raw_bounds.height > EPSILON) then
    return nil, tr("sh_perimeter_err_extent", "The drawing has no geometric extent.")
  end
  local factor = 2 ^ (drawing_scale - 1)
  local sx, sy = scale_x / (100 * factor), scale_y / (100 * factor)
  local transform = {
    sx = sx,
    sy = sy,
    ox = position.x - raw_bounds.width * sx * ax,
    oy = position.y - raw_bounds.height * sy * ay
  }
  local screen_contours = transform_contours(contours, transform)
  local screen_bounds = path_bounds(screen_contours)
  return {
    text = tostring(text),
    prefix = prefix,
    drawing = parts.drawing,
    suffix = parts.suffix,
    position = position,
    alignment = alignment,
    drawing_scale = drawing_scale,
    scale_x = scale_x,
    scale_y = scale_y,
    contours = contours,
    raw_bounds = raw_bounds,
    screen_contours = screen_contours,
    screen_bounds = screen_bounds
  }
end
local lerp_point
lerp_point = function(a, b, t)
  return point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
end
local split_cubic
split_cubic = function(segment)
  local p01 = lerp_point(segment.p0, segment.p1, 0.5)
  local p12 = lerp_point(segment.p1, segment.p2, 0.5)
  local p23 = lerp_point(segment.p2, segment.p3, 0.5)
  local p012 = lerp_point(p01, p12, 0.5)
  local p123 = lerp_point(p12, p23, 0.5)
  local middle = lerp_point(p012, p123, 0.5)
  return cubic_segment(segment.p0, p01, p012, middle), cubic_segment(middle, p123, p23, segment.p3)
end
local flatten_cubic
flatten_cubic = function(segment, tolerance)
  if tolerance == nil then
    tolerance = CURVE_TOLERANCE
  end
  local samples = {
    {
      t = 0,
      p = segment.p0
    }
  }
  local recurse
  recurse = function(curve, t0, t1, depth)
    local chord = distance(curve.p0, curve.p3)
    local polygon = distance(curve.p0, curve.p1) + distance(curve.p1, curve.p2) + distance(curve.p2, curve.p3)
    if depth >= MAX_CURVE_DEPTH or polygon - chord <= tolerance then
      samples[#samples + 1] = {
        t = t1,
        p = curve.p3
      }
      return
    end
    local left, right = split_cubic(curve)
    local middle = (t0 + t1) * 0.5
    recurse(left, t0, middle, depth + 1)
    return recurse(right, middle, t1, depth + 1)
  end
  recurse(segment, 0, 1, 0)
  return samples
end
local segment_start_tangent
segment_start_tangent = function(segment)
  if segment.kind == "line" then
    return normalize(segment.p1.x - segment.p0.x, segment.p1.y - segment.p0.y)
  end
  local tangent = cubic_derivative(segment, 0)
  return normalize(tangent.x, tangent.y) or normalize(segment.p3.x - segment.p0.x, segment.p3.y - segment.p0.y)
end
local segment_end_tangent
segment_end_tangent = function(segment)
  if segment.kind == "line" then
    return normalize(segment.p1.x - segment.p0.x, segment.p1.y - segment.p0.y)
  end
  local tangent = cubic_derivative(segment, 1)
  return normalize(tangent.x, tangent.y) or normalize(segment.p3.x - segment.p0.x, segment.p3.y - segment.p0.y)
end
local build_arc
build_arc = function(contour)
  if not (contour.closed) then
    return nil, tr("sh_perimeter_err_closed", "The perimeter contour must be closed.")
  end
  if #contour.segments == 0 then
    return nil, tr("sh_perimeter_err_segments", "The perimeter contour has no segments.")
  end
  local pieces, starts, total = { }, { }, 0
  for index, segment in ipairs(contour.segments) do
    starts[index] = total
    if segment.kind == "line" then
      local length = distance(segment.p0, segment.p1)
      if length > EPSILON then
        pieces[#pieces + 1] = {
          kind = "line",
          segment = segment,
          start = total,
          length = length,
          p0 = segment.p0,
          p1 = segment.p1
        }
        total = total + length
      end
    else
      local samples = flatten_cubic(segment)
      for sample_index = 2, #samples do
        local a, b = samples[sample_index - 1], samples[sample_index]
        local length = distance(a.p, b.p)
        if length > EPSILON then
          pieces[#pieces + 1] = {
            kind = "cubic",
            segment = segment,
            t0 = a.t,
            t1 = b.t,
            start = total,
            length = length,
            p0 = a.p,
            p1 = b.p
          }
          total = total + length
        end
      end
    end
  end
  if not (total > EPSILON) then
    return nil, tr("sh_perimeter_err_zero_length", "The perimeter contour has zero length.")
  end
  local boundaries = { }
  local count = #contour.segments
  for index, segment in ipairs(contour.segments) do
    local previous = contour.segments[((index - 2) % count) + 1]
    local incoming = segment_end_tangent(previous)
    local outgoing = segment_start_tangent(segment)
    boundaries[#boundaries + 1] = {
      distance = starts[index],
      point = segment.p0,
      incoming = incoming,
      outgoing = outgoing
    }
  end
  return {
    contour = contour,
    pieces = pieces,
    boundaries = boundaries,
    length = total
  }
end
local arc_area
arc_area = function(arc)
  local points = { }
  points[#points + 1] = arc.pieces[1].p0
  local _list_0 = arc.pieces
  for _index_0 = 1, #_list_0 do
    local piece = _list_0[_index_0]
    points[#points + 1] = piece.p1
  end
  local area = 0
  for index, a in ipairs(points) do
    local b = points[(index % #points) + 1]
    area = area + (a.x * b.y - b.x * a.y)
  end
  return area * 0.5
end
local arc_points
arc_points = function(arc)
  local points = {
    arc.pieces[1].p0
  }
  local _list_0 = arc.pieces
  for _index_0 = 1, #_list_0 do
    local piece = _list_0[_index_0]
    points[#points + 1] = piece.p1
  end
  return points
end
local arc_bounds
arc_bounds = function(arc)
  local bounds = new_bounds()
  local _list_0 = arc_points(arc)
  for _index_0 = 1, #_list_0 do
    local p = _list_0[_index_0]
    include_point(bounds, p)
  end
  return bounds
end
local point_on_segment
point_on_segment = function(p, a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local cross = dx * (p.y - a.y) - dy * (p.x - a.x)
  if math.abs(cross) > CORNER_EPSILON * math.max(1, math.abs(dx) + math.abs(dy)) then
    return false
  end
  local dot = (p.x - a.x) * dx + (p.y - a.y) * dy
  return dot >= -CORNER_EPSILON and dot <= dx * dx + dy * dy + CORNER_EPSILON
end
local point_in_arc
point_in_arc = function(p, arc)
  local points = arc_points(arc)
  local inside = false
  for index = 1, #points - 1 do
    local a, b = points[index], points[index + 1]
    if point_on_segment(p, a, b) then
      return -1
    end
    if (a.y > p.y) ~= (b.y > p.y) then
      local crossing_x = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)
      if crossing_x > p.x then
        inside = not inside
      end
    end
  end
  if not same_point(points[#points], points[1]) then
    local a, b = points[#points], points[1]
    if point_on_segment(p, a, b) then
      return -1
    end
    if (a.y > p.y) ~= (b.y > p.y) then
      local crossing_x = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)
      if crossing_x > p.x then
        inside = not inside
      end
    end
  end
  if inside then
    return 1
  else
    return 0
  end
end
local arc_contains
arc_contains = function(outer, inner)
  if not (math.abs(outer.area) > math.abs(inner.area) + EPSILON) then
    return false
  end
  if inner.bounds.l < outer.bounds.l - CORNER_EPSILON or inner.bounds.t < outer.bounds.t - CORNER_EPSILON then
    return false
  end
  if inner.bounds.r > outer.bounds.r + CORNER_EPSILON or inner.bounds.b > outer.bounds.b + CORNER_EPSILON then
    return false
  end
  local strictly_inside = false
  local _list_0 = arc_points(inner)
  for _index_0 = 1, #_list_0 do
    local p = _list_0[_index_0]
    local state = point_in_arc(p, outer)
    if state == 0 then
      return false
    end
    if state == 1 then
      strictly_inside = true
    end
  end
  return strictly_inside
end
local outer_arcs
outer_arcs = function(contours, include_holes)
  if include_holes == nil then
    include_holes = false
  end
  local arcs = { }
  for source_index, contour in ipairs(contours) do
    if contour.closed then
      local arc = build_arc(contour)
      if arc then
        arc.area = arc_area(arc)
        arc.bounds = arc_bounds(arc)
        arc.source_index = source_index
        arcs[#arcs + 1] = arc
      end
    end
  end
  if #arcs == 0 then
    return nil, tr("sh_perimeter_err_base_closed", "The base shape contains no usable closed contour.")
  end
  local selected = { }
  for _index_0 = 1, #arcs do
    local candidate = arcs[_index_0]
    local containers, outside_winding = 0, 0
    for _index_1 = 1, #arcs do
      local container = arcs[_index_1]
      if container ~= candidate and arc_contains(container, candidate) then
        containers = containers + 1
        outside_winding = outside_winding + (function()
          if container.area > 0 then
            return 1
          else
            return -1
          end
        end)()
      end
    end
    local own_winding
    if candidate.area > 0 then
      own_winding = 1
    else
      own_winding = -1
    end
    local inside_winding = outside_winding + own_winding
    candidate.depth = containers
    candidate.visible_boundary = (outside_winding == 0) ~= (inside_winding == 0)
    candidate.is_hole = candidate.visible_boundary and outside_winding ~= 0 and inside_winding == 0
    if candidate.visible_boundary and (include_holes or not candidate.is_hole) then
      selected[#selected + 1] = candidate
    end
  end
  if #selected == 0 then
    return nil, tr("sh_perimeter_err_visible", "The base shape contains no usable visible perimeter.")
  end
  return selected
end
local outer_arc
outer_arc = function(contours)
  local arcs, arcs_err = outer_arcs(contours)
  if not (arcs) then
    return nil, arcs_err
  end
  local best, best_area = nil, -math.huge
  for _index_0 = 1, #arcs do
    local arc = arcs[_index_0]
    local area = math.abs(arc.area)
    if area > best_area then
      best, best_area = arc, area
    end
  end
  return best
end
local corner_tangent
corner_tangent = function(incoming, outgoing)
  if not (incoming and outgoing) then
    return outgoing or incoming
  end
  local bisector = normalize(incoming.x + outgoing.x, incoming.y + outgoing.y)
  return bisector or outgoing
end
local arc_point
arc_point = function(arc, target)
  local length = arc.length
  target = target % length
  if target < 0 then
    target = target + length
  end
  local _list_0 = arc.boundaries
  for _index_0 = 1, #_list_0 do
    local boundary = _list_0[_index_0]
    local delta = math.abs(target - boundary.distance)
    delta = math.min(delta, length - delta)
    if delta <= CORNER_EPSILON then
      return {
        point = boundary.point,
        tangent = corner_tangent(boundary.incoming, boundary.outgoing),
        distance = target,
        corner = true
      }
    end
  end
  local low, high = 1, #arc.pieces
  while low < high do
    local middle = math.floor((low + high) * 0.5)
    local piece = arc.pieces[middle]
    if target >= piece.start + piece.length then
      low = middle + 1
    else
      high = middle
    end
  end
  local piece = arc.pieces[low]
  local ratio = math.max(0, math.min(1, (target - piece.start) / piece.length))
  if piece.kind == "line" then
    local tangent = normalize(piece.p1.x - piece.p0.x, piece.p1.y - piece.p0.y)
    return {
      point = lerp_point(piece.p0, piece.p1, ratio),
      tangent = tangent,
      distance = target,
      corner = false
    }
  end
  local t = piece.t0 + (piece.t1 - piece.t0) * ratio
  local position = cubic_point(piece.segment, t)
  local derivative = cubic_derivative(piece.segment, t)
  local tangent = normalize(derivative.x, derivative.y) or normalize(piece.p1.x - piece.p0.x, piece.p1.y - piece.p0.y)
  return {
    point = position,
    tangent = tangent,
    distance = target,
    corner = false,
    t = t
  }
end
local style_map = ShapeCore.styleMaps
local selection_indices = ShapeCore.selectionIndices
local prepare_line
prepare_line = function(line, index, styles, folded)
  local style_name = tostring(line.style or "")
  local style = ShapeCore.styleFor(styles, folded, style_name)
  if not (style) then
    return nil, tr("sh_err_style", "Line %d: style '%s' was not found.", index, style_name)
  end
  local shape, err = prepare_shape(line.text, style)
  if not (shape) then
    return nil, tr("sh_err_line", "Line %d: %s", index, err)
  end
  return {
    index = index,
    line = line,
    shape = shape
  }
end
local extend_bounds
extend_bounds = function(target, source)
  target.l = math.min(target.l, source.l)
  target.t = math.min(target.t, source.t)
  target.r = math.max(target.r, source.r)
  target.b = math.max(target.b, source.b)
end
local analyze_selection
analyze_selection = function(subs, sel)
  local indices = selection_indices(subs, sel)
  if #indices < 2 then
    return nil, tr("sh_perimeter_err_selection", "Select the base shape first, followed by at least one unit.")
  end
  local styles, folded = style_map(subs)
  local base, base_err = prepare_line(subs[indices[1]], indices[1], styles, folded)
  if not (base) then
    return nil, base_err
  end
  local all_arcs, arcs_err = outer_arcs(base.shape.screen_contours, true)
  if not (all_arcs) then
    return nil, tr("sh_perimeter_err_base_line", "Base line %d: %s", indices[1], arcs_err)
  end
  local arcs, holes = { }, { }
  for _index_0 = 1, #all_arcs do
    local arc = all_arcs[_index_0]
    if arc.is_hole then
      holes[#holes + 1] = arc
    else
      arcs[#arcs + 1] = arc
    end
  end
  if #arcs == 0 then
    return nil, tr("sh_perimeter_err_base_exterior", "Base line %d contains no usable exterior contour.", indices[1])
  end
  local groups, order = { }, { }
  for offset = 2, #indices do
    local index = indices[offset]
    local item, item_err = prepare_line(subs[index], index, styles, folded)
    if not (item) then
      return nil, item_err
    end
    local position = item.shape.position
    local key = tostring(format_number(position.x)) .. ":" .. tostring(format_number(position.y))
    local group = groups[key]
    if not (group) then
      group = {
        key = key,
        position = {
          x = position.x,
          y = position.y
        },
        lines = { },
        bounds = new_bounds()
      }
      groups[key] = group
      order[#order + 1] = group
    end
    if not (math.abs(position.x - group.position.x) <= EPSILON and math.abs(position.y - group.position.y) <= EPSILON) then
      return nil, tr("sh_perimeter_err_shared_pos", "All layers in a unit must share exactly the same \\pos.")
    end
    group.lines[#group.lines + 1] = item
    extend_bounds(group.bounds, item.shape.screen_bounds)
  end
  if #order == 0 then
    return nil, tr("sh_perimeter_err_no_units", "No units were detected after the base shape.")
  end
  local pattern_width = 0
  for _index_0 = 1, #order do
    local group = order[_index_0]
    group.min_x = group.bounds.l - group.position.x
    group.max_x = group.bounds.r - group.position.x
    group.width = group.max_x - group.min_x
    group.height = group.bounds.b - group.bounds.t
    if not (group.width > EPSILON) then
      return nil, tr("sh_perimeter_err_zero_width", "A unit has zero visible width.")
    end
    pattern_width = pattern_width + group.width
  end
  local perimeter_length, all_perimeter_length = 0, 0
  for _index_0 = 1, #arcs do
    local arc = arcs[_index_0]
    perimeter_length = perimeter_length + arc.length
  end
  for _index_0 = 1, #all_arcs do
    local arc = all_arcs[_index_0]
    all_perimeter_length = all_perimeter_length + arc.length
  end
  return {
    indices = indices,
    base = base,
    arc = arcs[1],
    arcs = arcs,
    all_arcs = all_arcs,
    holes = holes,
    perimeter_length = perimeter_length,
    all_perimeter_length = all_perimeter_length,
    units = order,
    pattern_width = pattern_width,
    template_indices = (function()
      local _accum_0 = { }
      local _len_0 = 1
      for index = 2, #indices do
        _accum_0[_len_0] = indices[index]
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)()
  }
end
local default_pattern
default_pattern = function(analysis)
  local pattern = { }
  for index = 1, #analysis.units do
    pattern[#pattern + 1] = index
  end
  return pattern
end
local copy_pattern
copy_pattern = function(source)
  local _accum_0 = { }
  local _len_0 = 1
  for _index_0 = 1, #source do
    local value = source[_index_0]
    _accum_0[_len_0] = value
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
local pattern_label
pattern_label = function(pattern)
  return table.concat(pattern, " -> ")
end
local pattern_width
pattern_width = function(analysis, pattern)
  if not (pattern and #pattern > 0) then
    return nil, tr("sh_perimeter_err_empty_period", "The period cannot be empty.")
  end
  local width = 0
  for _index_0 = 1, #pattern do
    local unit_index = pattern[_index_0]
    if not (unit_index == math.floor(unit_index) and analysis.units[unit_index]) then
      return nil, tr("sh_perimeter_err_invalid_unit", "The period contains an invalid unit.")
    end
    width = width + analysis.units[unit_index].width
  end
  return width
end
local perimeter_arcs
perimeter_arcs = function(analysis, include_holes)
  if include_holes == nil then
    include_holes = false
  end
  if include_holes and analysis.all_arcs then
    return analysis.all_arcs
  else
    return analysis.arcs or {
      analysis.arc
    }
  end
end
local automatic_cycles
automatic_cycles = function(analysis, pattern, include_holes)
  if pattern == nil then
    pattern = nil
  end
  if include_holes == nil then
    include_holes = false
  end
  if not (pattern) then
    pattern = default_pattern(analysis)
  end
  local width, width_err = pattern_width(analysis, pattern)
  if not (width) then
    return nil, width_err
  end
  local arcs = perimeter_arcs(analysis, include_holes)
  local cycles
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #arcs do
      local arc = arcs[_index_0]
      _accum_0[_len_0] = math.max(1, math.floor(arc.length / width + 0.5))
      _len_0 = _len_0 + 1
    end
    cycles = _accum_0
  end
  if #cycles == 1 then
    return cycles[1]
  else
    return cycles
  end
end
local build_pattern_options
build_pattern_options = function(analysis)
  local count = #analysis.units
  local items, patterns, seen = { }, { }, { }
  local add_pattern
  add_pattern = function(pattern)
    local key = table.concat(pattern, ",")
    if seen[key] then
      return
    end
    seen[key] = true
    local label = pattern_label(pattern)
    items[#items + 1] = label
    patterns[label] = copy_pattern(pattern)
  end
  for shift = 0, count - 1 do
    local pattern = { }
    for offset = 0, count - 1 do
      pattern[#pattern + 1] = ((shift + offset) % count) + 1
    end
    add_pattern(pattern)
  end
  for shift = 0, count - 1 do
    local pattern = { }
    for offset = 0, count - 1 do
      pattern[#pattern + 1] = ((shift - offset) % count) + 1
    end
    add_pattern(pattern)
  end
  if count > 2 then
    local pattern = default_pattern(analysis)
    for index = count - 1, 2, -1 do
      pattern[#pattern + 1] = index
    end
    add_pattern(pattern)
  end
  for unit_index = 1, count do
    add_pattern({
      unit_index
    })
  end
  local custom_label = tr("sh_perimeter_custom", "Custom...")
  items[#items + 1] = custom_label
  return items, patterns, custom_label
end
local custom_pattern_dialog
custom_pattern_dialog = function(analysis)
  local unit_items
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, #analysis.units do
      _accum_0[_len_0] = tr("sh_perimeter_unit", "Unit %d", index)
      _len_0 = _len_0 + 1
    end
    unit_items = _accum_0
  end
  local length_items
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, MAX_CUSTOM_PERIOD do
      _accum_0[_len_0] = tostring(index)
      _len_0 = _len_0 + 1
    end
    length_items = _accum_0
  end
  local default_length = math.min(#analysis.units, MAX_CUSTOM_PERIOD)
  local gui = {
    {
      class = "label",
      label = tr("sh_perimeter_period_length", "Period length:"),
      x = 0,
      y = 0,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "period_length",
      items = length_items,
      value = tostring(default_length),
      x = 1,
      y = 0,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = tr("sh_perimeter_period_hint", "Only the first steps selected by the length are used."),
      x = 0,
      y = 1,
      width = 4,
      height = 1
    }
  }
  local half = math.ceil(MAX_CUSTOM_PERIOD / 2)
  for step = 1, MAX_CUSTOM_PERIOD do
    local column
    if step <= half then
      column = 0
    else
      column = 2
    end
    local row = 2 + ((step - 1) % half)
    local default_unit = ((step - 1) % #analysis.units) + 1
    gui[#gui + 1] = {
      class = "label",
      label = tr("sh_perimeter_step", "Step %d:", step),
      x = column,
      y = row,
      width = 1,
      height = 1
    }
    gui[#gui + 1] = {
      class = "dropdown",
      name = "step_" .. tostring(step),
      items = unit_items,
      value = unit_items[default_unit],
      x = column + 1,
      y = row,
      width = 1,
      height = 1
    }
  end
  local apply, cancel = tr("sh_apply", "Apply"), tr("sh_cancel", "Cancel")
  local button, values = aegisub.dialog.display(gui, {
    apply,
    cancel
  }, {
    ok = apply,
    cancel = cancel
  })
  if button ~= apply then
    return nil
  end
  local length = tonumber(values.period_length)
  if not (length and length == math.floor(length) and length >= 1 and length <= MAX_CUSTOM_PERIOD) then
    return nil, tr("sh_perimeter_err_period_length", "The period length is invalid.")
  end
  local pattern = { }
  for step = 1, length do
    local unit_index = tonumber(tostring(values["step_" .. tostring(step)] or ""):match("(%d+)$"))
    if not (unit_index and analysis.units[unit_index]) then
      return nil, tr("sh_perimeter_err_step", "Step %d does not contain a valid unit.", step)
    end
    pattern[#pattern + 1] = unit_index
  end
  return pattern
end
local build_layout
build_layout = function(analysis, cycles, pattern, include_holes)
  if pattern == nil then
    pattern = nil
  end
  if include_holes == nil then
    include_holes = false
  end
  if not (pattern) then
    pattern = default_pattern(analysis)
  end
  local width, width_err = pattern_width(analysis, pattern)
  if not (width) then
    return nil, width_err
  end
  local units = analysis.units
  local arcs = perimeter_arcs(analysis, include_holes)
  local placements, gaps, cycle_counts, total_count = { }, { }, { }, 0
  for arc_index, arc in ipairs(arcs) do
    local arc_cycles
    if type(cycles) == "table" then
      arc_cycles = tonumber(cycles[arc_index])
    else
      arc_cycles = tonumber(cycles)
    end
    if not (arc_cycles and arc_cycles == math.floor(arc_cycles) and arc_cycles >= 1) then
      return nil, tr("sh_perimeter_err_cycles", "The repetition count for contour %d is invalid.", arc_index)
    end
    local count = #pattern * arc_cycles
    local gap = (arc.length - width * arc_cycles) / count
    local first = units[pattern[1]]
    local start_distance = -first.min_x + gap * 0.5
    local cursor = start_distance
    for placement_index = 1, count do
      local pattern_index = ((placement_index - 1) % #pattern) + 1
      local next_pattern_index = (pattern_index % #pattern) + 1
      local unit_index = pattern[pattern_index]
      local next_index = pattern[next_pattern_index]
      local unit, next_unit = units[unit_index], units[next_index]
      local sample = arc_point(arc, cursor)
      if not (sample and sample.tangent) then
        return nil, tr("sh_perimeter_err_tangent", "A tangent could not be calculated for contour %d.", arc_index)
      end
      local angle = -atan2(sample.tangent.y, sample.tangent.x) * 180 / math.pi
      placements[#placements + 1] = {
        unit = unit,
        unit_index = unit_index,
        point = sample.point,
        tangent = sample.tangent,
        angle = angle,
        distance = sample.distance,
        corner = sample.corner,
        arc_index = arc_index
      }
      local advance = unit.max_x - next_unit.min_x + gap
      if not (advance > EPSILON) then
        return nil, tr("sh_perimeter_err_advance", "Contour %d has too many repetitions: the advance between units is no longer positive.", arc_index)
      end
      cursor = cursor + advance
    end
    local expected = start_distance + arc.length
    if math.abs(cursor - expected) > 0.001 then
      return nil, tr("sh_perimeter_err_closure", "Pattern closure does not match contour %d.", arc_index)
    end
    gaps[arc_index] = gap
    cycle_counts[arc_index] = arc_cycles
    total_count = total_count + count
  end
  local gap
  if #gaps == 1 then
    gap = gaps[1]
  else
    gap = nil
  end
  local normalized_cycles
  if #cycle_counts == 1 then
    normalized_cycles = cycle_counts[1]
  else
    normalized_cycles = cycle_counts
  end
  return {
    placements = placements,
    gap = gap,
    gaps = gaps,
    cycles = normalized_cycles,
    count = total_count,
    pattern = copy_pattern(pattern),
    pattern_width = width
  }
end
local replace_position
replace_position = function(prefix, shape, position)
  local replacement = "\\pos(" .. tostring(format_number(position.x)) .. "," .. tostring(format_number(position.y)) .. ")"
  local mapped, count = prefix:gsub(shape.position.pattern, replacement)
  if not (count == 1) then
    return nil, tr("sh_perimeter_err_replace_pos", "A layer's \\pos could not be replaced.")
  end
  return mapped
end
local place_text
place_text = function(shape, placement)
  local prefix, err = replace_position(shape.prefix, shape, placement.point)
  if not (prefix) then
    return nil, err
  end
  local angle = placement.angle % 360
  if angle > 180 then
    angle = angle - 360
  end
  local rotation = "\\frz" .. tostring(format_number(angle))
  local count
  prefix, count = prefix:gsub("^{", "{" .. tostring(rotation), 1)
  if not (count == 1) then
    return nil, tr("sh_perimeter_err_rotation", "A layer's rotation could not be inserted.")
  end
  return prefix .. shape.drawing .. shape.suffix
end
local build_output
build_output = function(analysis, cycles, pattern, include_holes)
  if pattern == nil then
    pattern = nil
  end
  if include_holes == nil then
    include_holes = false
  end
  local layout, layout_err = build_layout(analysis, cycles, pattern, include_holes)
  if not (layout) then
    return nil, layout_err
  end
  local line_count = 0
  local _list_0 = layout.placements
  for _index_0 = 1, #_list_0 do
    local placement = _list_0[_index_0]
    line_count = line_count + #placement.unit.lines
  end
  if line_count > MAX_OUTPUT_LINES then
    return nil, tr("sh_perimeter_err_output_limit", "The output would contain %d lines; the safe limit is %d.", line_count, MAX_OUTPUT_LINES)
  end
  local lines = { }
  local _list_1 = layout.placements
  for _index_0 = 1, #_list_1 do
    local placement = _list_1[_index_0]
    local _list_2 = placement.unit.lines
    for _index_1 = 1, #_list_2 do
      local item = _list_2[_index_1]
      local text, text_err = place_text(item.shape, placement)
      if not (text) then
        return nil, tr("sh_perimeter_err_template", "Template line %d: %s", item.index, text_err)
      end
      local line = copy_line(item.line)
      line.text = text
      lines[#lines + 1] = line
    end
  end
  return {
    lines = lines,
    layout = layout
  }
end
local options_dialog
options_dialog = function(analysis, include_holes)
  if include_holes == nil then
    include_holes = false
  end
  local pattern_items, patterns, custom_label = build_pattern_options(analysis)
  local default_choice = pattern_items[1]
  local arcs = analysis.arcs or {
    analysis.arc
  }
  local holes = analysis.holes or { }
  local perimeter_length = analysis.perimeter_length or analysis.arc.length
  local hole_length = (analysis.all_perimeter_length or perimeter_length) - perimeter_length
  local gui = {
    {
      class = "label",
      label = tr("sh_perimeter_detected", "Detected units: %d", #analysis.units),
      x = 0,
      y = 0,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = tr("sh_perimeter_summary", "Exteriors: %d (%s px) | Holes: %d (%s px)", #arcs, format_number(perimeter_length, 2), #holes, format_number(hole_length, 2)),
      x = 0,
      y = 1,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = tr("sh_perimeter_pattern", "Periodic pattern:"),
      x = 0,
      y = 2,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "pattern",
      items = pattern_items,
      value = default_choice,
      x = 1,
      y = 2,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = tr("sh_perimeter_close_hint", "Each contour closes its period independently."),
      x = 0,
      y = 3,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = tr("sh_perimeter_order_hint", "Order: units 1, 2, 3... by their first \\pos in the selection."),
      x = 0,
      y = 4,
      width = 2,
      height = 1
    }
  }
  local apply, cancel = tr("sh_apply", "Apply"), tr("sh_cancel", "Cancel")
  local button, values = aegisub.dialog.display(gui, {
    apply,
    cancel
  }, {
    ok = apply,
    cancel = cancel
  })
  if button ~= apply then
    return nil
  end
  local choice = values.pattern
  local pattern = nil
  if choice == custom_label then
    local pattern_err
    pattern, pattern_err = custom_pattern_dialog(analysis)
    if pattern_err then
      return nil, pattern_err
    end
    if not (pattern) then
      return nil
    end
  else
    pattern = patterns[choice]
  end
  if not (pattern) then
    return nil, tr("sh_perimeter_err_pattern", "Choose a valid periodic pattern.")
  end
  local cycles, cycles_err = automatic_cycles(analysis, pattern, include_holes)
  if not (cycles) then
    return nil, cycles_err
  end
  return {
    cycles = cycles,
    pattern = pattern,
    include_holes = include_holes
  }
end
local apply_output
apply_output = function(subs, analysis, output)
  for offset = #analysis.template_indices, 1, -1 do
    subs.delete(analysis.template_indices[offset])
  end
  local selection = { }
  local insert_at = analysis.base.index + 1
  local _list_0 = output.lines
  for _index_0 = 1, #_list_0 do
    local line = _list_0[_index_0]
    subs.insert(insert_at, line)
    selection[#selection + 1] = insert_at
    insert_at = insert_at + 1
  end
  return selection
end
local main
main = function(subs, sel, active_line, context, settings)
  if settings == nil then
    settings = { }
  end
  set_context(context)
  local analysis, analysis_err = analyze_selection(subs, sel)
  if not (analysis) then
    return sel, false, analysis_err
  end
  local options, options_err = options_dialog(analysis, settings.include_holes == true)
  if options_err then
    return sel, false, options_err
  end
  if not (options) then
    return sel, false
  end
  local output, output_err = build_output(analysis, options.cycles, options.pattern, options.include_holes)
  if not (output) then
    return sel, false, output_err
  end
  local new_selection = apply_output(subs, analysis, output)
  if context and context.undo then
    context.undo("sh_undo_perimeter", "Rhea Signs: place shapes on perimeter")
  elseif aegisub and aegisub.set_undo_point then
    aegisub.set_undo_point(script_name)
  end
  return new_selection, true, output
end
return {
  name = script_name,
  description = script_description,
  version = script_version,
  set_context = set_context,
  prepare_shape = prepare_shape,
  parse_contours = parse_contours,
  path_bounds = path_bounds,
  build_arc = build_arc,
  outer_arcs = outer_arcs,
  outer_arc = outer_arc,
  arc_point = arc_point,
  analyze_selection = analyze_selection,
  default_pattern = default_pattern,
  pattern_width = pattern_width,
  perimeter_arcs = perimeter_arcs,
  automatic_cycles = automatic_cycles,
  build_pattern_options = build_pattern_options,
  build_layout = build_layout,
  build_output = build_output,
  options_dialog = options_dialog,
  apply_output = apply_output,
  main = main
}
end)()

local function translated(context, key, fallback)
    if context and type(context.translate) == "function" then
        local value = context.translate(key)
        if value and value ~= key then return value end
    end
    return fallback
end

local function optimize(subs, sel, options, context)
    SharedShapeOptimizer.setLanguage(context and context.language or "en")
    local normalized = SharedShapeOptimizer.normalizeOptions(options or {})
    local report, err = SharedShapeOptimizer.analyzeSelection(subs, sel, normalized)
    if not report then return sel, false, err end
    local summary = SharedShapeOptimizer.summaryText(report)
    if not report.changed then
        if context and context.show then context.show(translated(context, "sh_no_reduction", "No safe reduction was found with these parameters.") .. "\n\n" .. summary) end
        return sel, false, report
    end
    if normalized.show_summary and context and context.confirm then
        local prompt = summary .. "\n\n" .. translated(context, "sh_confirm_apply", "Apply direct replacement?")
        if not context.confirm(prompt) then return sel, false, report end
    end
    local newSelection = LineOps.transaction(subs, "", function()
        return SharedShapeOptimizer.applyReport(subs, report)
    end)
    if context and context.undo then context.undo("sh_undo_optimizer", "Rhea Signs: shape color optimizer") end
    if context and context.show and not context.silent then context.show(summary) end
    return newSelection, true, report
end

local function main(subs, sel, active, options, context)
    options = options or {}
    context = context or {}
    local result, changed, payload
    if options.action == "Unify Positions" then
        result, changed, payload = Unify.main(subs, sel, active, context)
    elseif options.action == "Place on Perimeter" then
        result, changed, payload = Perimeter.main(subs, sel, active, context, {
            include_holes = options.perimeter_mode == "Exterior contours and holes"
        })
    elseif options.action == "Shape Color Optimizer" then
        result, changed, payload = optimize(subs, sel, options, context)
    else
        return sel, false
    end
    if type(payload) == "string" and context.show then context.show(payload) end
    return result, changed, payload
end

return {
    main = main,
    optimize = optimize,
    unify = Unify,
    perimeter = Perimeter,
    colorOptimizer = SharedShapeOptimizer,
}

]====],
    ["Font and Style Manager"] = [====[
local FontSwap = { version = "1.3.0" }

local LANG = {
    en = {
        title = "Font and Style Manager",
        button_swap = "Swap",
        button_refresh = "Refresh",
        button_edit = "Edit",
        button_colors = "Colors",
        button_clone = "Clone",
        button_close = "Close",
        button_next = "Next",
        button_all = "All",
        button_apply = "Apply",
        button_cancel = "Cancel",
        button_ok = "OK",
        no_change = "No change",
        bool_on = "Enable",
        bool_off = "Disable",
        clone_exact = "Exact copy",
        clone_colors = "Change colors only",
        err_source_font = "Select a source font.",
        err_target_font = "Enter the target font.",
        err_unknown_styles = "These styles do not exist:\n\n%s",
        err_select_style = "Select at least one style.",
        err_no_styles = "The file contains no ASS styles.",
        err_empty_font = "The font cannot be empty.",
        err_select_field = "Mark at least one field to apply.",
        err_select_color = "Mark at least one color to apply.",
        err_clone_source = "The source style no longer exists.",
        err_clone_name = "Enter a name for the cloned style.",
        err_clone_chars = "The style name cannot contain commas or line breaks.",
        err_clone_exists = "A style with that name already exists.",
        err_base_style = "Select a valid base style.",
        one_style_per_line = "One style per line. Remove any style you do not want to edit.",
        mixed = "mixed",
        field_font = "Font",
        field_size = "Size",
        field_scale_x = "Scale X",
        field_scale_y = "Scale Y",
        field_spacing = "Spacing",
        field_angle = "Angle",
        field_outline = "Outline",
        field_shadow = "Shadow",
        field_margin_l = "Left margin",
        field_margin_r = "Right margin",
        field_margin_v = "Vertical margin",
        field_encoding = "Encoding",
        field_bold = "Bold",
        field_italic = "Italic",
        field_underline = "Underline",
        field_strikeout = "Strikeout",
        field_primary = "Primary",
        field_secondary = "Secondary",
        field_border = "Border",
        field_alignment = "Alignment",
        apply = "Apply",
        border_outline = "1 - Outline",
        border_opaque = "3 - Opaque box",
        edit_title = "Edit %d style(s)",
        edit_hint = "Only marked fields are applied.",
        choose_edit = "Styles to edit",
        choose_colors = "Styles whose colors will change",
        colors_title = "Change colors in %d style(s)",
        alpha_hint = "The picker includes the alpha channel.",
        copy_suffix = " - copy",
        clone_title = "Clone style",
        origin = "Source",
        name = "Name",
        mode = "Mode",
        font_summary = "%d style(s) · %d \\fn tag(s)",
        header = "%s · %d styles · %d fonts",
        detected_font = "Detected font",
        new_font = "New font",
        exact_font_hint = "Enter the exact font name.",
        replace_inline = "Also replace \\fn tags in dialogue lines",
        using_styles = "Styles using the selected font",
        base_style = "Base style to clone",
        no_matches = "No matching font references were found.",
        swap_done = "Font updated.\n\nStyles: %d\n\\fn tags: %d in %d line(s)",
        edit_done = "%d style(s) updated.\n%d value(s) changed.",
        colors_done = "%d style(s) updated.\n%d color(s) changed.",
        clone_created = "Style created: %s",
        undo_swap = "Font and Style Manager: swap font",
        undo_edit = "Font and Style Manager: edit styles",
        undo_colors = "Font and Style Manager: change colors",
        undo_clone = "Font and Style Manager: clone style",
    },
    es = {
        title = "Gestor de fuentes y estilos",
        button_swap = "Cambiar",
        button_refresh = "Actualizar",
        button_edit = "Editar",
        button_colors = "Colores",
        button_clone = "Clonar",
        button_close = "Cerrar",
        button_next = "Siguiente",
        button_all = "Todos",
        button_apply = "Aplicar",
        button_cancel = "Cancelar",
        button_ok = "Aceptar",
        no_change = "No cambiar",
        bool_on = "Activar",
        bool_off = "Desactivar",
        clone_exact = "Copia exacta",
        clone_colors = "Cambiar sólo colores",
        err_source_font = "Selecciona una fuente de origen.",
        err_target_font = "Escribe la fuente de destino.",
        err_unknown_styles = "Estos estilos no existen:\n\n%s",
        err_select_style = "Selecciona al menos un estilo.",
        err_no_styles = "El archivo no contiene estilos ASS.",
        err_empty_font = "La fuente no puede quedar vacía.",
        err_select_field = "Marca al menos un campo para aplicar.",
        err_select_color = "Marca al menos un color para aplicar.",
        err_clone_source = "El estilo de origen ya no existe.",
        err_clone_name = "Escribe un nombre para el clon.",
        err_clone_chars = "El nombre del estilo no puede contener comas ni saltos de línea.",
        err_clone_exists = "Ya existe un estilo con ese nombre.",
        err_base_style = "Selecciona un estilo base válido.",
        one_style_per_line = "Un estilo por línea. Borra los que no quieras modificar.",
        mixed = "mixto",
        field_font = "Fuente",
        field_size = "Tamaño",
        field_scale_x = "Escala X",
        field_scale_y = "Escala Y",
        field_spacing = "Espaciado",
        field_angle = "Ángulo",
        field_outline = "Contorno",
        field_shadow = "Sombra",
        field_margin_l = "Margen izquierdo",
        field_margin_r = "Margen derecho",
        field_margin_v = "Margen vertical",
        field_encoding = "Codificación",
        field_bold = "Negrita",
        field_italic = "Cursiva",
        field_underline = "Subrayado",
        field_strikeout = "Tachado",
        field_primary = "Primario",
        field_secondary = "Secundario",
        field_border = "Borde",
        field_alignment = "Alineación",
        apply = "Aplicar",
        border_outline = "1 - Contorno",
        border_opaque = "3 - Caja opaca",
        edit_title = "Editar %d estilo(s)",
        edit_hint = "Sólo se aplican los campos marcados.",
        choose_edit = "Estilos para editar",
        choose_colors = "Estilos cuyos colores cambiarán",
        colors_title = "Cambiar colores en %d estilo(s)",
        alpha_hint = "El selector incluye el canal alfa.",
        copy_suffix = " - copia",
        clone_title = "Clonar estilo",
        origin = "Origen",
        name = "Nombre",
        mode = "Modo",
        font_summary = "%d estilo(s) · %d etiqueta(s) \\fn",
        header = "%s · %d estilos · %d fuentes",
        detected_font = "Fuente detectada",
        new_font = "Nueva fuente",
        exact_font_hint = "Escribe el nombre exacto de la fuente.",
        replace_inline = "También reemplazar etiquetas \\fn en diálogos",
        using_styles = "Estilos que usan la fuente seleccionada",
        base_style = "Estilo base para clonar",
        no_matches = "No había coincidencias que cambiar.",
        swap_done = "Fuente actualizada.\n\nEstilos: %d\nEtiquetas \\fn: %d en %d línea(s)",
        edit_done = "%d estilo(s) actualizado(s).\n%d valor(es) cambiado(s).",
        colors_done = "%d estilo(s) actualizado(s).\n%d color(es) cambiado(s).",
        clone_created = "Estilo creado: %s",
        undo_swap = "Gestor de fuentes y estilos: cambiar fuente",
        undo_edit = "Gestor de fuentes y estilos: editar estilos",
        undo_colors = "Gestor de fuentes y estilos: cambiar colores",
        undo_clone = "Gestor de fuentes y estilos: clonar estilo",
    },
    pt = {
        title = "Gerenciador de fontes e estilos",
        button_swap = "Trocar",
        button_refresh = "Atualizar",
        button_edit = "Editar",
        button_colors = "Cores",
        button_clone = "Clonar",
        button_close = "Fechar",
        button_next = "Avançar",
        button_all = "Todos",
        button_apply = "Aplicar",
        button_cancel = "Cancelar",
        button_ok = "OK",
        no_change = "Não alterar",
        bool_on = "Ativar",
        bool_off = "Desativar",
        clone_exact = "Cópia exata",
        clone_colors = "Alterar somente as cores",
        err_source_font = "Selecione uma fonte de origem.",
        err_target_font = "Digite a fonte de destino.",
        err_unknown_styles = "Estes estilos não existem:\n\n%s",
        err_select_style = "Selecione ao menos um estilo.",
        err_no_styles = "O arquivo não contém estilos ASS.",
        err_empty_font = "A fonte não pode ficar vazia.",
        err_select_field = "Marque ao menos um campo para aplicar.",
        err_select_color = "Marque ao menos uma cor para aplicar.",
        err_clone_source = "O estilo de origem não existe mais.",
        err_clone_name = "Digite um nome para o clone.",
        err_clone_chars = "O nome do estilo não pode conter vírgulas nem quebras de linha.",
        err_clone_exists = "Já existe um estilo com esse nome.",
        err_base_style = "Selecione um estilo base válido.",
        one_style_per_line = "Um estilo por linha. Remova os que não deseja editar.",
        mixed = "misto",
        field_font = "Fonte",
        field_size = "Tamanho",
        field_scale_x = "Escala X",
        field_scale_y = "Escala Y",
        field_spacing = "Espaçamento",
        field_angle = "Ângulo",
        field_outline = "Contorno",
        field_shadow = "Sombra",
        field_margin_l = "Margem esquerda",
        field_margin_r = "Margem direita",
        field_margin_v = "Margem vertical",
        field_encoding = "Codificação",
        field_bold = "Negrito",
        field_italic = "Itálico",
        field_underline = "Sublinhado",
        field_strikeout = "Tachado",
        field_primary = "Primária",
        field_secondary = "Secundária",
        field_border = "Borda",
        field_alignment = "Alinhamento",
        apply = "Aplicar",
        border_outline = "1 - Contorno",
        border_opaque = "3 - Caixa opaca",
        edit_title = "Editar %d estilo(s)",
        edit_hint = "Somente os campos marcados serão aplicados.",
        choose_edit = "Estilos para editar",
        choose_colors = "Estilos cujas cores serão alteradas",
        colors_title = "Alterar cores em %d estilo(s)",
        alpha_hint = "O seletor inclui o canal alfa.",
        copy_suffix = " - cópia",
        clone_title = "Clonar estilo",
        origin = "Origem",
        name = "Nome",
        mode = "Modo",
        font_summary = "%d estilo(s) · %d etiqueta(s) \\fn",
        header = "%s · %d estilos · %d fontes",
        detected_font = "Fonte detectada",
        new_font = "Nova fonte",
        exact_font_hint = "Digite o nome exato da fonte.",
        replace_inline = "Também substituir etiquetas \\fn nas falas",
        using_styles = "Estilos que usam a fonte selecionada",
        base_style = "Estilo base para clonar",
        no_matches = "Nenhuma referência de fonte correspondente foi encontrada.",
        swap_done = "Fonte atualizada.\n\nEstilos: %d\nEtiquetas \\fn: %d em %d linha(s)",
        edit_done = "%d estilo(s) atualizado(s).\n%d valor(es) alterado(s).",
        colors_done = "%d estilo(s) atualizado(s).\n%d cor(es) alterada(s).",
        clone_created = "Estilo criado: %s",
        undo_swap = "Gerenciador de fontes e estilos: trocar fonte",
        undo_edit = "Gerenciador de fontes e estilos: editar estilos",
        undo_colors = "Gerenciador de fontes e estilos: alterar cores",
        undo_clone = "Gerenciador de fontes e estilos: clonar estilo",
    },
}

local current_language = "en"

local function T(key, ...)
    local value = (LANG[current_language] and LANG[current_language][key]) or LANG.en[key] or key
    if select("#", ...) == 0 then return value end
    return string.format(value, ...)
end

local STYLE_DEFAULTS = {
    fontname = "Arial",
    fontsize = 20,
    color1 = "&H00FFFFFF&",
    color2 = "&H000000FF&",
    color3 = "&H00000000&",
    color4 = "&H00000000&",
    bold = false,
    italic = false,
    underline = false,
    strikeout = false,
    scale_x = 100,
    scale_y = 100,
    spacing = 0,
    angle = 0,
    borderstyle = 1,
    outline = 2,
    shadow = 0,
    align = 2,
    margin_l = 10,
    margin_r = 10,
    margin_t = 10,
    encoding = 1,
}

local function trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function text_key(value)
    return trim(value):lower()
end

local function copy_table(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if key ~= "raw" then
            copy[key] = value
        end
    end
    return copy
end

local function show_message(message)
    aegisub.dialog.display({
        { class = "textbox", text = tostring(message or ""), x = 0, y = 0, width = 52, height = 8 },
    }, { T("button_ok") }, { close = T("button_ok") })
end

local function style_value(style, key)
    local value = style[key]
    if key == "margin_t" and value == nil then
        value = style.margin_v
        if value == nil then value = style.margin_b end
    end
    if value == nil then value = STYLE_DEFAULTS[key] end
    return value
end

local function set_style_value(style, key, value)
    style[key] = value
    if key == "margin_t" then
        style.margin_b = value
    end
end

local function collect_styles(subs)
    local list, by_name, by_key = {}, {}, {}
    for index = 1, #subs do
        local line = subs[index]
        if type(line) == "table" and line.class == "style" and trim(line.name) ~= "" then
            local record = { index = index, name = line.name, style = line }
            list[#list + 1] = record
            by_name[line.name] = record
            by_key[text_key(line.name)] = record
        end
    end
    table.sort(list, function(left, right)
        local left_key, right_key = text_key(left.name), text_key(right.name)
        if left_key == right_key then return left.name < right.name end
        return left_key < right_key
    end)
    return list, by_name, by_key
end

local function scan_inline_fonts(subs)
    local fonts = {}
    for index = 1, #subs do
        local line = subs[index]
        if type(line) == "table" and line.class == "dialogue" then
            for block in tostring(line.text or ""):gmatch("{([^}]*)}") do
                for fontname in block:gmatch("\\fn([^\\}]*)") do
                    fontname = trim(fontname)
                    if fontname ~= "" then
                        local key = text_key(fontname)
                        local entry = fonts[key]
                        if not entry then
                            entry = { name = fontname, count = 0 }
                            fonts[key] = entry
                        end
                        entry.count = entry.count + 1
                    end
                end
            end
        end
    end
    return fonts
end

local function collect_fonts(subs, styles)
    local fonts = {}
    for _, record in ipairs(styles) do
        local fontname = trim(style_value(record.style, "fontname"))
        if fontname ~= "" then
            local key = text_key(fontname)
            local entry = fonts[key]
            if not entry then
                entry = { name = fontname, style_count = 0, inline_count = 0 }
                fonts[key] = entry
            end
            entry.style_count = entry.style_count + 1
        end
    end
    for key, inline in pairs(scan_inline_fonts(subs)) do
        local entry = fonts[key]
        if not entry then
            entry = { name = inline.name, style_count = 0, inline_count = 0 }
            fonts[key] = entry
        end
        entry.inline_count = inline.count
    end

    local list = {}
    for _, entry in pairs(fonts) do list[#list + 1] = entry end
    table.sort(list, function(left, right)
        return text_key(left.name) < text_key(right.name)
    end)
    return list, fonts
end

local function style_names(styles)
    local names = {}
    for _, record in ipairs(styles) do names[#names + 1] = record.name end
    return names
end

local function matching_style_names(styles, fontname)
    local names, wanted = {}, text_key(fontname)
    for _, record in ipairs(styles) do
        if text_key(style_value(record.style, "fontname")) == wanted then
            names[#names + 1] = record.name
        end
    end
    return names
end

local function replace_inline_text(text, source_font, target_font)
    local source_key = text_key(source_font)
    local replacements = 0
    local updated = tostring(text or ""):gsub("{([^}]*)}", function(block)
        local replaced = block:gsub("(\\fn)([^\\}]*)", function(tag, value)
            if text_key(value) == source_key and value ~= target_font then
                replacements = replacements + 1
                return tag .. target_font
            end
            return tag .. value
        end)
        return "{" .. replaced .. "}"
    end)
    return updated, replacements
end

local function apply_font_swap(subs, source_font, target_font, replace_inline)
    source_font, target_font = trim(source_font), trim(target_font)
    if source_font == "" then return nil, T("err_source_font") end
    if target_font == "" then return nil, T("err_target_font") end

    local changed_styles, changed_tags, changed_lines = 0, 0, 0
    for index = 1, #subs do
        local line = subs[index]
        if type(line) == "table" and line.class == "style"
            and text_key(style_value(line, "fontname")) == text_key(source_font)
            and tostring(style_value(line, "fontname")) ~= target_font then
            line.fontname = target_font
            subs[index] = line
            changed_styles = changed_styles + 1
        elseif replace_inline and type(line) == "table" and line.class == "dialogue" then
            local updated, count = replace_inline_text(line.text, source_font, target_font)
            if count > 0 then
                line.text = updated
                subs[index] = line
                changed_tags = changed_tags + count
                changed_lines = changed_lines + 1
            end
        end
    end
    return {
        styles = changed_styles,
        tags = changed_tags,
        lines = changed_lines,
    }
end

local function parse_target_names(text, by_key)
    local names, seen, unknown = {}, {}, {}
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for row in (text .. "\n"):gmatch("(.-)\n") do
        local name = trim(row)
        if name ~= "" then
            local key = text_key(name)
            local record = by_key[key]
            if record and not seen[key] then
                names[#names + 1] = record.name
                seen[key] = true
            elseif not record then
                unknown[#unknown + 1] = name
            end
        end
    end
    return names, unknown
end

local function populated_line_count(text)
    local count = 0
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for row in (text .. "\n"):gmatch("(.-)\n") do
        if trim(row) ~= "" then count = count + 1 end
    end
    return count
end

local function choose_styles(subs, initial_names, title)
    local styles, _, by_key = collect_styles(subs)
    local all_names = style_names(styles)
    local current = table.concat(initial_names or {}, "\n")
    local button_next, button_all, button_cancel = T("button_next"), T("button_all"), T("button_cancel")
    while true do
        local list_height = math.min(12, math.max(4, populated_line_count(current)))
        local button, result = aegisub.dialog.display({
            { class = "label", label = title, x = 0, y = 0, width = 10, height = 1 },
            { class = "label", label = T("one_style_per_line"), x = 0, y = 1, width = 10, height = 1 },
            { class = "textbox", name = "targets", text = current, x = 0, y = 2, width = 10, height = list_height },
        }, { button_next, button_all, button_cancel }, { ok = button_next, close = button_cancel })

        if button == button_cancel or not button then return nil end
        if button == button_all then
            current = table.concat(all_names, "\n")
        else
            local names, unknown = parse_target_names(result.targets, by_key)
            if #unknown > 0 then
                show_message(T("err_unknown_styles", table.concat(unknown, "\n")))
                current = result.targets
            elseif #names == 0 then
                show_message(T("err_select_style"))
                current = result.targets
            else
                return names
            end
        end
    end
end

local function records_for_names(subs, names)
    local _, _, by_key = collect_styles(subs)
    local records = {}
    for _, name in ipairs(names or {}) do
        local record = by_key[text_key(name)]
        if record then records[#records + 1] = record end
    end
    return records
end

local function common_value(records, key)
    local first = style_value(records[1].style, key)
    for index = 2, #records do
        if style_value(records[index].style, key) ~= first then
            return first, true
        end
    end
    return first, false
end

local function mixed_label(label, mixed)
    return mixed and (label .. "  [" .. T("mixed") .. "]") or label
end

local PROPERTY_FIELDS = {
    { key = "fontname", label_key = "field_font", class = "edit", width = 7 },
    { key = "fontsize", label_key = "field_size", class = "floatedit", min = 0.1, max = 10000, step = 0.1 },
    { key = "scale_x", label_key = "field_scale_x", class = "floatedit", min = 0, max = 10000, step = 0.1 },
    { key = "scale_y", label_key = "field_scale_y", class = "floatedit", min = 0, max = 10000, step = 0.1 },
    { key = "spacing", label_key = "field_spacing", class = "floatedit", min = -10000, max = 10000, step = 0.1 },
    { key = "angle", label_key = "field_angle", class = "floatedit", min = -36000, max = 36000, step = 0.1 },
    { key = "outline", label_key = "field_outline", class = "floatedit", min = 0, max = 1000, step = 0.1 },
    { key = "shadow", label_key = "field_shadow", class = "floatedit", min = -1000, max = 1000, step = 0.1 },
    { key = "margin_l", label_key = "field_margin_l", class = "intedit", min = 0, max = 100000 },
    { key = "margin_r", label_key = "field_margin_r", class = "intedit", min = 0, max = 100000 },
    { key = "margin_t", label_key = "field_margin_v", class = "intedit", min = 0, max = 100000 },
    { key = "encoding", label_key = "field_encoding", class = "intedit", min = 0, max = 255 },
}

local BOOLEAN_FIELDS = {
    { key = "bold", label_key = "field_bold" },
    { key = "italic", label_key = "field_italic" },
    { key = "underline", label_key = "field_underline" },
    { key = "strikeout", label_key = "field_strikeout" },
}

local COLOR_FIELDS = {
    { key = "color1", label_key = "field_primary" },
    { key = "color2", label_key = "field_secondary" },
    { key = "color3", label_key = "field_outline" },
    { key = "color4", label_key = "field_shadow" },
}

local function apply_style_values(subs, names, values)
    local records = records_for_names(subs, names)
    local changed_styles, changed_fields = 0, 0
    for _, record in ipairs(records) do
        local style, changed = record.style, false
        for key, value in pairs(values or {}) do
            if style_value(style, key) ~= value then
                set_style_value(style, key, value)
                changed = true
                changed_fields = changed_fields + 1
            end
        end
        if changed then
            subs[record.index] = style
            changed_styles = changed_styles + 1
        end
    end
    return changed_styles, changed_fields
end

local function edit_properties(subs, names)
    local records = records_for_names(subs, names)
    if #records == 0 then return false end

    local dialog = {
        { class = "label", label = T("edit_title", #records), x = 0, y = 0, width = 11, height = 1 },
        { class = "label", label = T("edit_hint"), x = 0, y = 1, width = 11, height = 1 },
        { class = "textbox", text = table.concat(names, "\n"), x = 0, y = 2, width = 11, height = math.min(5, math.max(2, #names)) },
    }
    local row = 3 + math.min(5, math.max(2, #names))
    for _, field in ipairs(PROPERTY_FIELDS) do
        local value, mixed = common_value(records, field.key)
        dialog[#dialog + 1] = { class = "label", label = mixed_label(T(field.label_key), mixed), x = 0, y = row, width = 3, height = 1 }
        dialog[#dialog + 1] = { class = "checkbox", name = "apply_" .. field.key, label = T("apply"), value = false, x = 3, y = row, width = 2, height = 1 }
        local control = {
            class = field.class,
            name = field.key,
            x = 5,
            y = row,
            width = field.width or 6,
            height = 1,
        }
        if field.class == "edit" or field.class == "textbox" then
            control.text = value
        else
            control.value = value
        end
        if field.min ~= nil then control.min = field.min end
        if field.max ~= nil then control.max = field.max end
        if field.step ~= nil then control.step = field.step end
        dialog[#dialog + 1] = control
        row = row + 1
    end

    for _, field in ipairs(BOOLEAN_FIELDS) do
        local _, mixed = common_value(records, field.key)
        dialog[#dialog + 1] = { class = "label", label = mixed_label(T(field.label_key), mixed), x = 0, y = row, width = 3, height = 1 }
        dialog[#dialog + 1] = { class = "dropdown", name = field.key, items = { T("no_change"), T("bool_on"), T("bool_off") }, value = T("no_change"), x = 3, y = row, width = 8, height = 1 }
        row = row + 1
    end

    local border, border_mixed = common_value(records, "borderstyle")
    dialog[#dialog + 1] = { class = "label", label = mixed_label(T("field_border"), border_mixed), x = 0, y = row, width = 3, height = 1 }
    dialog[#dialog + 1] = { class = "checkbox", name = "apply_borderstyle", label = T("apply"), value = false, x = 3, y = row, width = 2, height = 1 }
    dialog[#dialog + 1] = { class = "dropdown", name = "borderstyle", items = { T("border_outline"), T("border_opaque") }, value = tonumber(border) == 3 and T("border_opaque") or T("border_outline"), x = 5, y = row, width = 6, height = 1 }
    row = row + 1

    local align, align_mixed = common_value(records, "align")
    local align_items = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
    dialog[#dialog + 1] = { class = "label", label = mixed_label(T("field_alignment"), align_mixed), x = 0, y = row, width = 3, height = 1 }
    dialog[#dialog + 1] = { class = "checkbox", name = "apply_align", label = T("apply"), value = false, x = 3, y = row, width = 2, height = 1 }
    dialog[#dialog + 1] = { class = "dropdown", name = "align", items = align_items, value = tostring(tonumber(align) or 2), x = 5, y = row, width = 6, height = 1 }

    local button_apply, button_cancel = T("button_apply"), T("button_cancel")
    while true do
        local button, result = aegisub.dialog.display(dialog, { button_apply, button_cancel }, { ok = button_apply, close = button_cancel })
        if button ~= button_apply then return false end

        local values = {}
        for _, field in ipairs(PROPERTY_FIELDS) do
            if result["apply_" .. field.key] then
                if field.key == "fontname" then
                    local fontname = trim(result.fontname)
                    if fontname == "" then
                        show_message(T("err_empty_font"))
                        values = nil
                        break
                    end
                    values.fontname = fontname
                else
                    values[field.key] = tonumber(result[field.key])
                end
            end
        end
        if values then
            for _, field in ipairs(BOOLEAN_FIELDS) do
                if result[field.key] == T("bool_on") then values[field.key] = true end
                if result[field.key] == T("bool_off") then values[field.key] = false end
            end
            if result.apply_borderstyle then values.borderstyle = tonumber(tostring(result.borderstyle):match("^%d+")) end
            if result.apply_align then values.align = tonumber(result.align) end

            if next(values) == nil then
                show_message(T("err_select_field"))
            else
                local changed_styles, changed_fields = apply_style_values(subs, names, values)
                return true, changed_styles, changed_fields
            end
        end
    end
end

local function edit_colors(subs, names)
    local records = records_for_names(subs, names)
    if #records == 0 then return false end
    local dialog = {
        { class = "label", label = T("colors_title", #records), x = 0, y = 0, width = 9, height = 1 },
        { class = "label", label = T("alpha_hint"), x = 0, y = 1, width = 9, height = 1 },
    }
    local row = 2
    for _, field in ipairs(COLOR_FIELDS) do
        local value, mixed = common_value(records, field.key)
        dialog[#dialog + 1] = { class = "label", label = mixed_label(T(field.label_key), mixed), x = 0, y = row, width = 3, height = 1 }
        dialog[#dialog + 1] = { class = "checkbox", name = "apply_" .. field.key, label = T("apply"), value = false, x = 3, y = row, width = 2, height = 1 }
        dialog[#dialog + 1] = { class = "coloralpha", name = field.key, value = value, x = 5, y = row, width = 4, height = 1 }
        row = row + 1
    end

    local button_apply, button_cancel = T("button_apply"), T("button_cancel")
    while true do
        local button, result = aegisub.dialog.display(dialog, { button_apply, button_cancel }, { ok = button_apply, close = button_cancel })
        if button ~= button_apply then return false end
        local values = {}
        for _, field in ipairs(COLOR_FIELDS) do
            if result["apply_" .. field.key] then values[field.key] = result[field.key] end
        end
        if next(values) == nil then
            show_message(T("err_select_color"))
        else
            local changed_styles, changed_fields = apply_style_values(subs, names, values)
            return true, changed_styles, changed_fields
        end
    end
end

local function next_clone_name(source_name, by_key)
    local base = trim(source_name) .. T("copy_suffix")
    local candidate, suffix = base, 2
    while by_key[text_key(candidate)] do
        candidate = base .. " " .. suffix
        suffix = suffix + 1
    end
    return candidate
end

local function style_insert_position(subs)
    local last_style, first_dialogue
    for index = 1, #subs do
        local class = subs[index] and subs[index].class
        if class == "style" then last_style = index end
        if class == "dialogue" and not first_dialogue then first_dialogue = index end
    end
    if last_style then return last_style + 1 end
    if first_dialogue then return first_dialogue end
    return #subs + 1
end

local function clone_style(subs, source_name, new_name, colors)
    local _, _, by_key = collect_styles(subs)
    local source = by_key[text_key(source_name)]
    if not source then return nil, T("err_clone_source") end
    new_name = trim(new_name)
    if new_name == "" then return nil, T("err_clone_name") end
    if new_name:find("[,\r\n]") then return nil, T("err_clone_chars") end
    if by_key[text_key(new_name)] then return nil, T("err_clone_exists") end

    local clone = copy_table(source.style)
    clone.class = "style"
    clone.name = new_name
    for key, value in pairs(colors or {}) do set_style_value(clone, key, value) end
    local insert_at = style_insert_position(subs)
    subs.insert(insert_at, clone)
    return insert_at, clone
end

local function clone_dialog(subs, source_name)
    local _, _, by_key = collect_styles(subs)
    local source = by_key[text_key(source_name)]
    if not source then
        show_message(T("err_base_style"))
        return nil
    end
    local default_name = next_clone_name(source.name, by_key)
    local style = source.style
    local button_clone, button_cancel = T("button_clone"), T("button_cancel")
    while true do
        local button, result = aegisub.dialog.display({
            { class = "label", label = T("clone_title"), x = 0, y = 0, width = 8, height = 1 },
            { class = "label", label = T("origin"), x = 0, y = 1, width = 2, height = 1 },
            { class = "label", label = source.name, x = 2, y = 1, width = 6, height = 1 },
            { class = "label", label = T("name"), x = 0, y = 2, width = 2, height = 1 },
            { class = "edit", name = "new_name", text = default_name, x = 2, y = 2, width = 6, height = 1 },
            { class = "label", label = T("mode"), x = 0, y = 3, width = 2, height = 1 },
            { class = "dropdown", name = "mode", items = { T("clone_exact"), T("clone_colors") }, value = T("clone_colors"), x = 2, y = 3, width = 6, height = 1 },
            { class = "label", label = T("field_primary"), x = 0, y = 4, width = 2, height = 1 },
            { class = "coloralpha", name = "color1", value = style_value(style, "color1"), x = 2, y = 4, width = 6, height = 1 },
            { class = "label", label = T("field_secondary"), x = 0, y = 5, width = 2, height = 1 },
            { class = "coloralpha", name = "color2", value = style_value(style, "color2"), x = 2, y = 5, width = 6, height = 1 },
            { class = "label", label = T("field_outline"), x = 0, y = 6, width = 2, height = 1 },
            { class = "coloralpha", name = "color3", value = style_value(style, "color3"), x = 2, y = 6, width = 6, height = 1 },
            { class = "label", label = T("field_shadow"), x = 0, y = 7, width = 2, height = 1 },
            { class = "coloralpha", name = "color4", value = style_value(style, "color4"), x = 2, y = 7, width = 6, height = 1 },
        }, { button_clone, button_cancel }, { ok = button_clone, close = button_cancel })

        if button ~= button_clone then return nil end
        local colors
        if result.mode == T("clone_colors") then
            colors = {
                color1 = result.color1,
                color2 = result.color2,
                color3 = result.color3,
                color4 = result.color4,
            }
        end
        local insert_at, clone_or_error = clone_style(subs, source.name, result.new_name, colors)
        if insert_at then return insert_at, clone_or_error end
        show_message(clone_or_error)
        default_name = result.new_name
    end
end

local function shift_selection(selection, insert_at)
    local shifted = {}
    for _, index in ipairs(selection or {}) do
        shifted[#shifted + 1] = index >= insert_at and (index + 1) or index
    end
    return shifted
end

local function font_summary(entry)
    if not entry then return "" end
    return T("font_summary", entry.style_count, entry.inline_count)
end

local function choose_existing(value, items, fallback)
    local wanted = text_key(value)
    for _, item in ipairs(items) do
        if text_key(item) == wanted then return item end
    end
    return fallback or items[1]
end

local function main(subs, selection, _, context)
    context = context or {}
    current_language = LANG[context.language] and context.language or "en"
    local state = { selected_font = nil, target_font = "", base_style = nil, replace_inline = false }
    local active_selection = selection or {}

    while true do
        local styles = collect_styles(subs)
        if #styles == 0 then
            show_message(T("err_no_styles"))
            return active_selection
        end
        local fonts, font_map = collect_fonts(subs, styles)
        local font_items = {}
        for _, entry in ipairs(fonts) do font_items[#font_items + 1] = entry.name end
        local all_style_names = style_names(styles)
        state.selected_font = choose_existing(state.selected_font, font_items, font_items[1])
        state.base_style = choose_existing(state.base_style, all_style_names, all_style_names[1])

        local matching = matching_style_names(styles, state.selected_font)
        local entry = font_map[text_key(state.selected_font)]
        local style_list_height = math.min(8, math.max(3, #matching))
        local base_style_row = 6 + style_list_height
        local button_swap = T("button_swap")
        local button_refresh = T("button_refresh")
        local button_edit = T("button_edit")
        local button_colors = T("button_colors")
        local button_clone = T("button_clone")
        local button_close = T("button_close")
        local button, result = aegisub.dialog.display({
            { class = "label", label = T("header", T("title"), #styles, #fonts), x = 0, y = 0, width = 10, height = 1 },
            { class = "label", label = T("detected_font"), x = 0, y = 1, width = 3, height = 1 },
            { class = "dropdown", name = "source_font", items = font_items, value = state.selected_font, x = 3, y = 1, width = 7, height = 1 },
            { class = "label", label = font_summary(entry), x = 0, y = 2, width = 10, height = 1 },
            { class = "label", label = T("new_font"), x = 0, y = 3, width = 3, height = 1 },
            { class = "edit", name = "target_font", text = state.target_font, hint = T("exact_font_hint"), x = 3, y = 3, width = 7, height = 1 },
            { class = "checkbox", name = "replace_inline", label = T("replace_inline"), value = state.replace_inline, x = 0, y = 4, width = 10, height = 1 },
            { class = "label", label = T("using_styles"), x = 0, y = 5, width = 10, height = 1 },
            { class = "textbox", text = table.concat(matching, "\n"), x = 0, y = 6, width = 10, height = style_list_height },
            { class = "label", label = T("base_style"), x = 0, y = base_style_row, width = 3, height = 1 },
            { class = "dropdown", name = "base_style", items = all_style_names, value = state.base_style, x = 3, y = base_style_row, width = 7, height = 1 },
        }, { button_swap, button_refresh, button_edit, button_colors, button_clone, button_close }, { ok = button_swap, close = button_close })

        if button == button_close or not button then return active_selection end
        state.selected_font = result.source_font
        state.target_font = result.target_font
        state.base_style = result.base_style
        state.replace_inline = result.replace_inline == true

        if button == button_swap then
            local counts, error_message = apply_font_swap(subs, state.selected_font, state.target_font, state.replace_inline)
            if not counts then
                show_message(error_message)
            elseif counts.styles + counts.tags == 0 then
                show_message(T("no_matches"))
            else
                aegisub.set_undo_point(T("undo_swap"))
                show_message(T("swap_done", counts.styles, counts.tags, counts.lines))
                state.selected_font = trim(state.target_font)
                state.target_font = ""
            end
        elseif button == button_edit then
            local targets = choose_styles(subs, matching_style_names(collect_styles(subs), state.selected_font), T("choose_edit"))
            if targets then
                local applied, changed_styles, changed_fields = edit_properties(subs, targets)
                if applied then
                    if changed_styles > 0 then aegisub.set_undo_point(T("undo_edit")) end
                    show_message(T("edit_done", changed_styles, changed_fields))
                end
            end
        elseif button == button_colors then
            local targets = choose_styles(subs, matching_style_names(collect_styles(subs), state.selected_font), T("choose_colors"))
            if targets then
                local applied, changed_styles, changed_fields = edit_colors(subs, targets)
                if applied then
                    if changed_styles > 0 then aegisub.set_undo_point(T("undo_colors")) end
                    show_message(T("colors_done", changed_styles, changed_fields))
                end
            end
        elseif button == button_clone then
            local insert_at, clone = clone_dialog(subs, state.base_style)
            if insert_at then
                active_selection = shift_selection(active_selection, insert_at)
                aegisub.set_undo_point(T("undo_clone"))
                state.base_style = clone.name
                show_message(T("clone_created", clone.name))
            end
        end
    end
end

FontSwap.main = main

return FontSwap
]====],
    ["Fast Fades"] = [====[
local script_name = "Fast Fades"
local script_description = "Frame-based fades and continuous fade cleanup"
local script_author = "Kiterow"
local script_version = "1.2.0"
local EventOps = require("kite.EventOps")
local LineOps = require("kite.LineOps")
local translate
translate = function(context, key, fallback, ...)
  local value = fallback
  if context and type(context.translate) == "function" then
    local translated = context.translate(key)
    if translated and translated ~= key then
      value = translated
    end
  end
  if select("#", ...) == 0 then
    return value
  end
  return string.format(value, ...)
end
local notify
notify = function(context, key, fallback, ...)
  local message = translate(context, key, fallback, ...)
  if context and type(context.show) == "function" then
    context.show(message)
  elseif context and type(context.notify_message) == "function" then
    context.notify_message(message)
  elseif context and type(context.notify) == "function" then
    context.notify(key, message)
  elseif aegisub and aegisub.dialog and aegisub.dialog.display then
    aegisub.dialog.display({
      {
        class = "label",
        label = message,
        x = 0,
        y = 0,
        width = 45,
        height = 2
      }
    }, {
      translate(context, "btn_ok", "OK")
    })
  end
  return message
end
local dialog
dialog = function(context, spec, buttons, options)
  if context and type(context.dialog) == "function" then
    return context.dialog(spec, buttons, options)
  end
  return aegisub.dialog.display(spec, buttons, options)
end
local editable_indices
editable_indices = function(subs, sel)
  local indices = { }
  local _list_0 = EventOps.dialogueIndices(subs, sel)
  for _index_0 = 1, #_list_0 do
    local index = _list_0[_index_0]
    local line = subs[index]
    if line and not line.comment then
      table.insert(indices, index)
    end
  end
  return indices
end
local current_frame_ms
current_frame_ms = function(context)
  if context and type(context.current_frame_ms) == "function" then
    return context.current_frame_ms()
  end
  if not (aegisub and aegisub.project_properties and aegisub.ms_from_frame) then
    return nil, "fade_err_frame_read"
  end
  local ok_props, props = pcall(aegisub.project_properties)
  if not (ok_props) then
    return nil, "fade_err_frame_read"
  end
  local frame = props and tonumber(props.video_position)
  if not (frame) then
    return nil, "fade_err_no_frame"
  end
  local ok_ms, ms = pcall(aegisub.ms_from_frame, frame)
  ms = tonumber(ms)
  if not (ok_ms and ms and ms == ms and ms ~= math.huge and ms ~= -math.huge) then
    return nil, "fade_err_frame_ms"
  end
  return ms
end
local apply_frame_fade
apply_frame_fade = function(subs, sel, mode, context)
  local indices = editable_indices(subs, sel)
  if #indices == 0 then
    notify(context, "fade_err_selection", "Select at least one dialogue line.")
    return sel, false
  end
  local frame_ms, frame_error = current_frame_ms(context)
  if not (frame_ms) then
    local messages = {
      fade_err_frame_read = "The current video frame could not be read.",
      fade_err_no_frame = "There is no active video frame.",
      fade_err_frame_ms = "The current frame could not be converted to milliseconds."
    }
    notify(context, frame_error, messages[frame_error] or messages.fade_err_frame_read)
    return sel, false
  end
  local updates = { }
  for _index_0 = 1, #indices do
    local index = indices[_index_0]
    local line = subs[index]
    local start_time = tonumber(line.start_time)
    local end_time = tonumber(line.end_time)
    if not (start_time and end_time and frame_ms >= start_time and frame_ms < end_time) then
      notify(context, "fade_err_frame_inside", "The current frame must be inside every selected line.")
      return sel, false
    end
    local duration
    if mode == "in" then
      duration = frame_ms - start_time
    else
      duration = end_time - frame_ms
    end
    duration = math.floor(duration + 0.5)
    local text, update_error = EventOps.setFadeComponent(line.text, mode, duration)
    if not (text) then
      local fallback
      if update_error == "invalid_fad" then
        fallback = "Line %d contains an invalid \\fad tag."
      else
        fallback = "Line %d could not be updated."
      end
      notify(context, "fade_err_line", fallback, index)
      return sel, false
    end
    table.insert(updates, {
      index = index,
      text = text
    })
  end
  for _index_0 = 1, #updates do
    local update = updates[_index_0]
    local line = subs[update.index]
    line.text = update.text
    subs[update.index] = line
  end
  if context and type(context.undo) == "function" then
    local key
    if mode == "in" then
      key = "fade_undo_intro"
    else
      key = "fade_undo_outro"
    end
    local fallback
    if mode == "in" then
      fallback = "Rhea Signs: fade in from current frame"
    else
      fallback = "Rhea Signs: fade out from current frame"
    end
    context.undo(key, fallback)
  elseif aegisub and aegisub.set_undo_point then
    aegisub.set_undo_point((function()
      if mode == "in" then
        return "Fast Fades - fade in"
      else
        return "Fast Fades - fade out"
      end
    end)())
  end
  return sel, true
end
local cleanup
cleanup = function(subs, sel, context)
  local indices = EventOps.dialogueIndices(subs, sel)
  local groups = { }
  for _index_0 = 1, #indices do
    local index = indices[_index_0]
    local line = subs[index]
    groups[tostring(line.start_time) .. "\31" .. tostring(line.end_time)] = true
  end
  local count = 0
  for _ in pairs(groups) do
    count = count + 1
  end
  if count < 2 then
    notify(context, "fade_err_cleanup_groups", "Select at least two timing groups.")
    return sel, false
  end
  local result, changed = LineOps.transaction(subs, "", function()
    return EventOps.continuousFadeCleanup(subs, indices)
  end)
  if changed > 0 then
    if context and type(context.undo) == "function" then
      context.undo("fade_undo_cleanup", "Rhea Signs: continuous fade cleanup")
    elseif aegisub and aegisub.set_undo_point then
      aegisub.set_undo_point("Fast Fades - continuous cleanup")
    end
  end
  return result, changed > 0
end
local run
run = function(subs, sel, action, context)
  if action == "Fade In from Current Frame" then
    return apply_frame_fade(subs, sel, "in", context)
  end
  if action == "Fade Out from Current Frame" then
    return apply_frame_fade(subs, sel, "out", context)
  end
  if action == "Continuous Fade Cleanup" then
    return cleanup(subs, sel, context)
  end
  return sel, false
end
local main
main = function(subs, sel, active, context)
  local fade_in = translate(context, "fade_action_intro", "In")
  local fade_out = translate(context, "fade_action_outro", "Out")
  local continuous = translate(context, "fade_action_cleanup", "Clean")
  local cancel = translate(context, "fade_cancel", "Cancel")
  local button = dialog(context, {
    {
      class = "label",
      label = translate(context, "fade_prompt", "Choose a fade operation:"),
      x = 0,
      y = 0,
      width = 22,
      height = 1
    }
  }, {
    fade_in,
    fade_out,
    continuous,
    cancel
  }, {
    close = cancel
  })
  if not (button and button ~= cancel) then
    return sel, false
  end
  if button == fade_in then
    return run(subs, sel, "Fade In from Current Frame", context)
  end
  if button == fade_out then
    return run(subs, sel, "Fade Out from Current Frame", context)
  end
  return run(subs, sel, "Continuous Fade Cleanup", context)
end
return {
  name = script_name,
  version = script_version,
  main = main,
  run = run,
  applyFrameFade = apply_frame_fade,
  cleanup = cleanup
}

]====],
    ["Shuffle Line Text"] = [====[
local SharedEventOps = require("kite.EventOps")
local SharedLineOps = require("kite.LineOps")
local function main(subs, sel, active, context)
    context = context or {}
    local indices = SharedEventOps.dialogueIndices(subs, sel)
    if #indices < 2 then
        if type(context.notify) == "function" then
            context.notify("tool_err_shuffle_lines", "Select at least two dialogue lines.")
        end
        return sel
    end
    local result, changed = SharedLineOps.transaction(subs, "", function()
        return SharedEventOps.shuffleLineText(subs, indices)
    end)
    if changed > 0 and type(context.undo) == "function" then
        context.undo("tool_undo_shuffle_line_text", "Rhea Signs: shuffle line text")
    end
    return result
end
return { main = main }
]====],
}
local TOOLBOX_ACTIONS = {
    "Font and Style Manager",
    "Fast Fades",
    "Shuffle Line Text",
}
local integratedToolCache = {}

local function loadIntegratedTool(name)
    if integratedToolCache[name] then return integratedToolCache[name] end
    local source = INTEGRATED_TOOL_SOURCES[name]
    if not source then return nil, name end

    local chunk, err = loadstring(source, "@Rhea Signs/" .. name)
    if not chunk then return nil, err end

    local environment = setmetatable({
        Rhea = Rhea,
        RheaFoundation = RheaFoundation,
        LineOps = LineOps,
    }, {__index = _G})
    setfenv(chunk, environment)
    local ok, tool = pcall(chunk)
    if not ok then return nil, tool end
    if type(tool) ~= "table" or type(tool.main) ~= "function" then
        return nil, "missing main entrypoint"
    end
    integratedToolCache[name] = tool
    INTEGRATED_TOOL_SOURCES[name] = nil
    return tool
end

local function integratedTool(name)
    local tool, err = loadIntegratedTool(name)
    if tool then return tool end
    showMsg(string.format(L("err_tool_load"), choiceLabel(name), tostring(err)), nil, {width=60, height=6})
end

local function integratedToolContext()
    return {
        language = current_lang,
        translate = L,
        current_frame_ms = RheaFoundation.currentFrameMs,
        dialog = function(spec, buttons, options)
            return aegisub.dialog.display(spec, buttons, options)
        end,
        notify = function(key, fallback)
            local message = L(key)
            if message == key then message = fallback end
            if aegisub and aegisub.log then pcall(aegisub.log, tostring(message or "") .. "\n") end
        end,
        notify_message = function(message)
            if aegisub and aegisub.log then pcall(aegisub.log, tostring(message or "") .. "\n") end
        end,
        undo = function(key, fallback)
            local label = L(key)
            if label == key then label = fallback end
            if aegisub and aegisub.set_undo_point then aegisub.set_undo_point(label) end
        end,
        show = function(message)
            return showMsg(tostring(message or ""), nil, {width=60, height=8})
        end,
        confirm = function(message)
            local apply, cancel = L("sh_apply"), L("sh_cancel")
            local button = aegisub.dialog.display({
                {class="textbox", value=tostring(message or ""), x=0, y=0, width=56, height=10}
            }, {apply, cancel}, {ok=apply, close=cancel})
            return button == apply
        end,
    }
end

local SHAPE_DEFAULTS = {
    perimeter_mode = "Exterior contours only",
    optimizer_mode = "Auto",
    intensity = "Balanced",
    threshold = 0,
    max_bands = 8,
    show_summary = false,
}
local SHAPE_CONFIG = RheaConfig.section("sh", SHAPE_DEFAULTS)

local tagops_gui, config_gui
local function row_master_gui(subs, sel, active)
    resolveConfig()
    if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end

    local pkc = RheaOps.Perspective.loadConfig()
    local drc = FunctionalTable.union(RheaOps.Masks.loadConfig() or {}, RheaOps.Masks.defaults or {})
    local soc = RheaOps.Sign.loadConfig()
    local shc = SHAPE_CONFIG.read()

    local state = {
        pk_action = "", pk_map = pkc.map or "ABCD (exact copy)", pk_orgm = pkc.orgm or "3 minimize fax",
        pk_set_sx = pkc.set_sx or false, pk_sx = pkc.sx or 100,
        pk_set_sy = pkc.set_sy or false, pk_sy = pkc.sy or 100,
        pk_qscale = pkc.qscale or 100,

        dr_action = "", dr_mask_source = drc.mask_source or "from clip",
        dr_alignment = drc.alignment or "an7", dr_create_layer = drc.create_layer ~= false,
        dr_replace_mask = drc.replace_mask or false, dr_bicubic = drc.bicubic or false,
        dr_use_alpha = drc.use_alpha or false, dr_alpha_value = drc.alpha_value or "80",
        dr_use_color = drc.use_color ~= false, dr_mask_color = drc.color_value or "#000000", dr_save_name = "",

        so_action = "", so_type_mode = soc.type_mode or "Frame",
        so_vertical_gap = tonumber(soc.vertical_gap) or 0,
        so_circ_rot = soc.circ_rot or "Normal", so_circ_radio = soc.circ_radio or 0,
        so_circ_track = soc.circ_track or 0, so_circ_invert = soc.circ_invert or false,
        so_circ_delete = soc.circ_delete or false,

        shape_action = "",
        shape_perimeter_mode = RheaFoundation.choose(shc.perimeter_mode, {"Exterior contours only", "Exterior contours and holes"}, SHAPE_DEFAULTS.perimeter_mode),
        shape_optimizer_mode = RheaFoundation.choose(shc.optimizer_mode, SharedShapeOptimizer.modes, SHAPE_DEFAULTS.optimizer_mode),
        shape_intensity = RheaFoundation.choose(shc.intensity, SharedShapeOptimizer.intensities, SHAPE_DEFAULTS.intensity),
        shape_threshold = RheaFoundation.configNumber(shc.threshold, SHAPE_DEFAULTS.threshold, 0, 0.25),
        shape_max_bands = RheaFoundation.configNumber(shc.max_bands, SHAPE_DEFAULTS.max_bands, 2, 64),
        shape_show_summary = shc.show_summary == true,

        tool_action = "",
    }
    local function syncMainGlobalColors()
        if current_config.mask_color ~= nil then state.dr_mask_color = current_config.mask_color end
    end
    syncMainGlobalColors()

    while true do
        local pkItems, pkMap, pkShown = dropdownData(RheaOps.Perspective.modes)
        local pkMapItems, pkMapMap, pkMapShown = dropdownData(RheaOps.Perspective.mapNames())
        local pkOrgItems, pkOrgMap, pkOrgShown = dropdownData(RheaOps.Perspective.orgModes)
        local soActionItems, soActionMap, soActionShown = dropdownData({ "Typewriter", "Vertical Drop", "Circle Text", "Curve Text", "Clean SiO" })
        local soTypeItems, soTypeMap, soTypeShown = dropdownData({ "Frame", "Duration" })
        local soRotItems, soRotMap, soRotShown = dropdownData({ "Normal", "Invertido", "Vertical" })
        local drActionItems, drActionMap, drActionShown = dropdownData({ "Apply Mask", "Create Layer", "Replace Mask", "Save Shape", "Delete Shape", "Clean DR" })
        local drMaskItems, drMaskMap, drMaskShown = dropdownData(RheaOps.Masks.maskNames())
        local drAlignItems, drAlignMap, drAlignShown = dropdownData({"an1", "an2", "an3", "an4", "an5", "an6", "an7", "an8", "an9"})
        local drAlphaItems, drAlphaMap, drAlphaShown = dropdownData({"00", "20", "40", "60", "80", "A0", "C0", "E0", "FF"})
        local shapeActionItems, shapeActionMap, shapeActionShown = dropdownData({"Unify Positions", "Place on Perimeter", "Shape Color Optimizer"})
        local shapePerimeterItems, shapePerimeterMap, shapePerimeterShown = dropdownData({"Exterior contours only", "Exterior contours and holes"})
        local shapeModeItems, shapeModeMap, shapeModeShown = dropdownData(SharedShapeOptimizer.modes)
        local shapeIntensityItems, shapeIntensityMap, shapeIntensityShown = dropdownData(SharedShapeOptimizer.intensities)
        local toolItems, toolMap, toolShown = dropdownData(TOOLBOX_ACTIONS)
        local dropdownMaps = {
            pk_action = pkMap, pk_map = pkMapMap, pk_orgm = pkOrgMap,
            so_action = soActionMap, so_type_mode = soTypeMap, so_circ_rot = soRotMap,
            dr_action = drActionMap, dr_mask_source = drMaskMap, dr_alignment = drAlignMap, dr_alpha_value = drAlphaMap,
            shape_action = shapeActionMap, shape_perimeter_mode = shapePerimeterMap,
            shape_optimizer_mode = shapeModeMap, shape_intensity = shapeIntensityMap,
            tool_action = toolMap,
        }
        local maskX, perspX, shapeX, signX = 0, 5, 0, 5
        local d = {
            { class="label", label=sectionTitle("title_masks"), x=maskX, y=0, width=5, height=1 },
            { class="label", label=L("lbl_mask"), x=maskX, y=1, width=1, height=1 },
            { class="dropdown", name="dr_action", items=drActionItems, value=shownChoice(drActionShown, state.dr_action), x=maskX + 1, y=1, width=4, height=1 },
            { class="label", label=L("lbl_source"), x=maskX, y=2, width=1, height=1 },
            { class="dropdown", name="dr_mask_source", items=drMaskItems, value=shownChoice(drMaskShown, state.dr_mask_source), x=maskX + 1, y=2, width=4, height=1 },
            { class="label", label=L("lbl_align"), x=maskX, y=3, width=1, height=1 },
            { class="dropdown", name="dr_alignment", items=drAlignItems, value=shownChoice(drAlignShown, state.dr_alignment), x=maskX + 1, y=3, width=1, height=1 },
            { class="label", label=L("lbl_alpha"), x=maskX + 2, y=3, width=1, height=1 },
            { class="dropdown", name="dr_alpha_value", items=drAlphaItems, value=shownChoice(drAlphaShown, state.dr_alpha_value), x=maskX + 3, y=3, width=2, height=1 },
            { class="checkbox", name="dr_create_layer", label=L("lbl_layer"), value=state.dr_create_layer, x=maskX, y=4, width=2, height=1 },
            { class="checkbox", name="dr_replace_mask", label=L("lbl_replace"), value=state.dr_replace_mask, x=maskX + 2, y=4, width=3, height=1 },
            { class="checkbox", name="dr_bicubic", label="q2", value=state.dr_bicubic, x=maskX, y=5, width=1, height=1 },
            { class="checkbox", name="dr_use_color", label=L("lbl_color"), value=state.dr_use_color, x=maskX + 1, y=5, width=1, height=1 },
            { class="coloralpha", name="dr_mask_color", value=state.dr_mask_color, x=maskX + 2, y=5, width=2, height=1 },
            { class="checkbox", name="dr_use_alpha", label="A", value=state.dr_use_alpha, x=maskX + 4, y=5, width=1, height=1 },
            { class="label", label=L("lbl_name"), x=maskX, y=6, width=1, height=1 },
            { class="edit", name="dr_save_name", value=state.dr_save_name, x=maskX + 1, y=6, width=4, height=1 },

            { class="label", label=sectionTitle("title_perspectiva"), x=perspX, y=0, width=5, height=1 },
            { class="label", label=L("lbl_mode"), x=perspX, y=1, width=1, height=1 },
            { class="dropdown", name="pk_action", items=pkItems, value=shownChoice(pkShown, state.pk_action), x=perspX + 1, y=1, width=4, height=1 },
            { class="label", label=L("lbl_map"), x=perspX, y=2, width=1, height=1 },
            { class="dropdown", name="pk_map", items=pkMapItems, value=shownChoice(pkMapShown, state.pk_map), x=perspX + 1, y=2, width=4, height=1 },
            { class="label", label=L("lbl_org"), x=perspX, y=3, width=1, height=1 },
            { class="dropdown", name="pk_orgm", items=pkOrgItems, value=shownChoice(pkOrgShown, state.pk_orgm), x=perspX + 1, y=3, width=4, height=1 },
            { class="checkbox", name="pk_set_sx", label=L("lbl_x"), value=state.pk_set_sx, x=perspX, y=4, width=1, height=1 },
            { class="floatedit", name="pk_sx", value=state.pk_sx, min=1, x=perspX + 1, y=4, width=2, height=1 },
            { class="checkbox", name="pk_set_sy", label=L("lbl_y"), value=state.pk_set_sy, x=perspX, y=5, width=1, height=1 },
            { class="floatedit", name="pk_sy", value=state.pk_sy, min=1, x=perspX + 1, y=5, width=2, height=1 },
            { class="label", label=L("lbl_quad"), x=perspX, y=6, width=1, height=1 },
            { class="floatedit", name="pk_qscale", value=state.pk_qscale, min=1, x=perspX + 1, y=6, width=2, height=1 },

            { class="label", label=sectionTitle("title_shapes"), x=shapeX, y=7, width=5, height=1 },
            { class="label", label=L("lbl_action"), x=shapeX, y=8, width=1, height=1 },
            { class="dropdown", name="shape_action", items=shapeActionItems, value=shownChoice(shapeActionShown, state.shape_action), hint=L("sh_hint_action"), x=shapeX + 1, y=8, width=4, height=1 },
            { class="label", label=L("lbl_perimeter"), x=shapeX, y=9, width=1, height=1 },
            { class="dropdown", name="shape_perimeter_mode", items=shapePerimeterItems, value=shownChoice(shapePerimeterShown, state.shape_perimeter_mode), hint=L("sh_hint_perimeter_mode"), x=shapeX + 1, y=9, width=4, height=1 },
            { class="label", label=L("lbl_mode"), x=shapeX, y=10, width=1, height=1 },
            { class="dropdown", name="shape_optimizer_mode", items=shapeModeItems, value=shownChoice(shapeModeShown, state.shape_optimizer_mode), hint=L("sh_hint_optimizer_mode"), x=shapeX + 1, y=10, width=4, height=1 },
            { class="label", label=L("lbl_intensity"), x=shapeX, y=11, width=1, height=1 },
            { class="dropdown", name="shape_intensity", items=shapeIntensityItems, value=shownChoice(shapeIntensityShown, state.shape_intensity), hint=L("sh_hint_intensity"), x=shapeX + 1, y=11, width=4, height=1 },
            { class="label", label=L("lbl_threshold"), x=shapeX, y=12, width=1, height=1 },
            { class="floatedit", name="shape_threshold", value=state.shape_threshold, min=0, max=0.25, step=0.005, hint=L("sh_hint_threshold"), x=shapeX + 1, y=12, width=1, height=1 },
            { class="label", label=L("lbl_bands"), x=shapeX + 2, y=12, width=1, height=1 },
            { class="intedit", name="shape_max_bands", value=state.shape_max_bands, min=2, max=64, hint=L("sh_hint_bands"), x=shapeX + 3, y=12, width=2, height=1 },
            { class="checkbox", name="shape_show_summary", label=L("sh_show_summary"), value=state.shape_show_summary, x=shapeX, y=13, width=5, height=1 },

            { class="label", label=sectionTitle("title_signlayout"), x=signX, y=7, width=5, height=1 },
            { class="label", label=L("lbl_sign"), x=signX, y=8, width=1, height=1 },
            { class="dropdown", name="so_action", items=soActionItems, value=shownChoice(soActionShown, state.so_action), x=signX + 1, y=8, width=4, height=1 },
            { class="label", label=L("lbl_type"), x=signX, y=9, width=1, height=1 },
            { class="dropdown", name="so_type_mode", items=soTypeItems, value=shownChoice(soTypeShown, state.so_type_mode), x=signX + 1, y=9, width=4, height=1 },
            { class="label", label=L("lbl_rot"), x=signX, y=10, width=1, height=1 },
            { class="dropdown", name="so_circ_rot", items=soRotItems, value=shownChoice(soRotShown, state.so_circ_rot), x=signX + 1, y=10, width=4, height=1 },
            { class="label", label=L("lbl_radius"), x=signX, y=11, width=1, height=1 },
            { class="floatedit", name="so_circ_radio", value=state.so_circ_radio, x=signX + 1, y=11, width=2, height=1 },
            { class="checkbox", name="so_circ_invert", label=L("lbl_inv"), value=state.so_circ_invert, x=signX + 3, y=11, width=2, height=1 },
            { class="label", label=L("lbl_track"), x=signX, y=12, width=1, height=1 },
            { class="floatedit", name="so_circ_track", value=state.so_circ_track, x=signX + 1, y=12, width=2, height=1 },
            { class="checkbox", name="so_circ_delete", label=L("lbl_del"), value=state.so_circ_delete, x=signX + 3, y=12, width=2, height=1 },
            { class="label", label=L("lbl_vertical_gap"), x=signX, y=13, width=2, height=1 },
            { class="floatedit", name="so_vertical_gap", value=state.so_vertical_gap, min=-10000, max=10000, step=0.1, x=signX + 2, y=13, width=3, height=1 },

            { class="label", label=sectionTitle("title_toolbox"), x=0, y=14, width=2, height=1 },
            { class="dropdown", name="tool_action", items=toolItems, value=shownChoice(toolShown, state.tool_action), x=2, y=14, width=8, height=1 },
        }
        local buttons = { L("btn_execute"), L("btn_mass_signs"), L("btn_fastsigns"), L("btn_tagops"), L("btn_config"), L("btn_help"), L("btn_cancel") }
        local b, r = aegisub.dialog.display(d, buttons)
        if not b or b == L("btn_cancel") then return end

        for k, v in pairs(r) do
            local m = dropdownMaps[k]
            state[k] = m and rawChoice(m, v) or v
        end
        r = state

        if b == L("btn_help") then
            aegisub.dialog.display({
                { class="textbox", text=helpText(), x=0, y=0, width=50, height=22 }
            }, { L("btn_ok") })

        elseif b == L("btn_mass_signs") then
            if RheaOps.Tools.massSigns(subs, sel) then return end

        elseif b == L("btn_fastsigns") then
            RheaOps.Tools.fastSigns(subs, sel)
            return

        elseif b == L("btn_tagops") then
            if tagops_gui(subs, sel) then return end

        elseif b == L("btn_config") then
            if config_gui() then syncMainGlobalColors() end

        elseif b == L("btn_execute") then
            local tsel = sel
            local any_run = (r.pk_action ~= "" or r.dr_action ~= "" or r.shape_action ~= "" or r.so_action ~= "" or r.tool_action ~= "")
            if not any_run then return end
            local function updateChainSelection(result, changed)
                if changed ~= false and type(result) == "table" then tsel = result end
            end

            if r.pk_action ~= "" then
                local perspectiveResult = RheaOps.Perspective.run(subs, tsel, {
                    mode = r.pk_action, map = r.pk_map, orgm = r.pk_orgm,
                    set_sx = r.pk_set_sx, sx = tonumber(r.pk_sx) or 100,
                    set_sy = r.pk_set_sy, sy = tonumber(r.pk_sy) or 100,
                    qscale = tonumber(r.pk_qscale) or 100,
                })
                if perspectiveResult ~= true then return end
            end

            if r.dr_action ~= "" then
                local drcfg = {
                    mask_source = r.dr_mask_source, alignment = r.dr_alignment,
                    create_layer = r.dr_create_layer, replace_mask = r.dr_replace_mask,
                    bicubic = r.dr_bicubic, use_alpha = r.dr_use_alpha,
                    alpha_value = r.dr_alpha_value, use_color = r.dr_use_color,
                    color_value = r.dr_mask_color,
                }
                if r.dr_mask_color and r.dr_mask_color ~= current_config.mask_color then
                    current_config.mask_color = r.dr_mask_color
                    saveGlobalConfig()
                end
                if r.dr_action == "Save Shape" then
                    local name = Rhea.trim(r.dr_save_name or "")
                    if name ~= "" and tsel[1] then
                        local ok, err = RheaOps.Masks.saveMask(name, subs[tsel[1]].text)
                        if not ok then showMsg(tostring(err or "No se pudo guardar la máscara.")) end
                    end
                    RheaOps.Masks.saveConfig(drcfg)
                elseif r.dr_action == "Delete Shape" then
                    local name = Rhea.trim(r.dr_save_name or "")
                    if name ~= "" then
                        local ok, err = RheaOps.Masks.deleteMask(name)
                        if not ok then showMsg(tostring(err or "No se pudo eliminar la máscara.")) end
                    end
                    RheaOps.Masks.saveConfig(drcfg)
                else
                    if r.dr_action == "Clean DR" then drcfg.op = "clean"
                    elseif r.dr_action == "Create Layer" then drcfg.create_layer = true; drcfg.replace_mask = false
                    elseif r.dr_action == "Replace Mask" then drcfg.replace_mask = true end
                    local result, changed = RheaOps.Masks.run(subs, tsel, drcfg)
                    updateChainSelection(result, changed)
                end
            end

            if r.shape_action ~= "" then
                SHAPE_CONFIG.write({
                    perimeter_mode = r.shape_perimeter_mode,
                    optimizer_mode = r.shape_optimizer_mode,
                    intensity = r.shape_intensity,
                    threshold = tonumber(r.shape_threshold) or SHAPE_DEFAULTS.threshold,
                    max_bands = tonumber(r.shape_max_bands) or SHAPE_DEFAULTS.max_bands,
                    show_summary = r.shape_show_summary == true,
                })
                local shapeActive, activeSelected = tonumber(active), false
                for _, index in ipairs(tsel or {}) do
                    if index == shapeActive then activeSelected = true; break end
                end
                if not activeSelected then shapeActive = tsel and tsel[1] end
                local tool = integratedTool("Shapes")
                if not tool then return end
                local result, changed = tool.main(subs, tsel, shapeActive, {
                    action = r.shape_action,
                    perimeter_mode = r.shape_perimeter_mode,
                    mode = r.shape_optimizer_mode,
                    intensity = r.shape_intensity,
                    threshold = tonumber(r.shape_threshold) or 0,
                    max_bands = tonumber(r.shape_max_bands) or 8,
                    show_summary = r.shape_show_summary == true,
                }, integratedToolContext())
                updateChainSelection(result, changed)
            end

            if r.so_action ~= "" then
                local sop = ({
                    ["Typewriter"] = "typewriter", ["Vertical Drop"] = "vertical_drop",
                    ["Circle Text"] = "circle_text", ["Curve Text"] = "curve_text",
                    ["Clean SiO"] = "clean_sio",
                })[r.so_action]
                local result, changed = RheaOps.Sign.run(subs, tsel, {
                    op = sop, type_mode = r.so_type_mode,
                    vertical_gap = tonumber(r.so_vertical_gap) or 0,
                    circ_rot = r.so_circ_rot,
                    circ_radio = tonumber(r.so_circ_radio) or 0,
                    circ_track = tonumber(r.so_circ_track) or 0,
                    circ_invert = r.so_circ_invert,
                    circ_delete = r.so_circ_delete,
                })
                updateChainSelection(result, changed)
            end

            if r.tool_action ~= "" then
                local tool = integratedTool(r.tool_action)
                if tool then return tool.main(subs, tsel, nil, integratedToolContext()) end
            end

            return
        end
    end
end

tagops_gui = function(subs, sel)
    resolveConfig()
    if not sel or #sel == 0 then showMsg(L("err_no_selection")); return false end

    local actionItems, actionMap, actionShown = dropdownData(TagOps.actions)
    local modeItems, modeMap, modeShown = dropdownData({"Add", "Percent", "Transform"})
    local alignOrgItems, alignOrgMap, alignOrgShown = dropdownData({"Keep org", "Move org"})
    local savedAction = tagopsNormalizeAction(current_config.tagops_action or "Resize / transform")
    local state = {
        tagops_action = savedAction,
        tagops_amount = current_config.tagops_amount or 0,
        tagops_mode = current_config.tagops_mode or "Add",
        tagops_align_org = current_config.tagops_align_org or "Keep org",
        tagops_replace = current_config.tagops_replace ~= false,
        tagops_all_blocks = current_config.tagops_all_blocks or false,
        tagops_append = current_config.tagops_append or false,
        tagops_info = current_config.tagops_info or false,
    }
    for _, def in ipairs(TagOps.defs) do
        state["tagops_" .. def.key] = current_config["tagops_" .. def.key] or false
    end

    local d = {
        {class="label", label=L("tagops_title"), x=0, y=0, width=8, height=1},
        {class="label", label=L("lbl_action"), x=0, y=1, width=2, height=1},
        {class="dropdown", name="tagops_action", items=actionItems, value=shownChoice(actionShown, state.tagops_action), x=2, y=1, width=4, height=1},
        {class="label", label=L("lbl_org"), x=0, y=2, width=2, height=1},
        {class="dropdown", name="tagops_align_org", items=alignOrgItems, value=shownChoice(alignOrgShown, state.tagops_align_org), x=2, y=2, width=4, height=1},
        {class="label", label=L("lbl_amount"), x=0, y=3, width=2, height=1},
        {class="floatedit", name="tagops_amount", value=state.tagops_amount, x=2, y=3, width=1, height=1},
        {class="dropdown", name="tagops_mode", items=modeItems, value=shownChoice(modeShown, state.tagops_mode), x=3, y=3, width=3, height=1},
        {class="checkbox", name="tagops_replace", label=L("tagops_replace"), value=state.tagops_replace, x=0, y=4, width=6, height=1},
        {class="checkbox", name="tagops_all_blocks", label=L("tagops_read_all"), value=state.tagops_all_blocks, x=0, y=5, width=6, height=1},
        {class="checkbox", name="tagops_append", label=L("tagops_append"), value=state.tagops_append, x=0, y=6, width=6, height=1},
        {class="checkbox", name="tagops_info", label=L("tagops_show_result"), value=state.tagops_info, x=0, y=7, width=6, height=1},
    }
    for index, def in ipairs(TagOps.defs) do
        local col = (index - 1) % 6
        local row = math.floor((index - 1) / 6)
        d[#d + 1] = {class="checkbox", name="tagops_" .. def.key, label=def.label, value=state["tagops_" .. def.key], x=col, y=9 + row, width=1, height=1}
    end

    local b, r = aegisub.dialog.display(d, {L("btn_execute"), L("btn_copy_tags"), L("btn_keep_only"), L("btn_cancel")})
    if b == L("btn_cancel") or not b then return false end

    r.tagops_action = tagopsNormalizeAction(rawChoice(actionMap, r.tagops_action))
    r.tagops_mode = rawChoice(modeMap, r.tagops_mode)
    r.tagops_align_org = rawChoice(alignOrgMap, r.tagops_align_org)
    current_config.tagops_action = r.tagops_action
    current_config.tagops_amount = r.tagops_amount
    current_config.tagops_mode = r.tagops_mode
    current_config.tagops_align_org = r.tagops_align_org
    current_config.tagops_replace = r.tagops_replace
    current_config.tagops_all_blocks = r.tagops_all_blocks
    current_config.tagops_append = r.tagops_append
    current_config.tagops_info = r.tagops_info

    local selected = {}
    for _, def in ipairs(TagOps.defs) do
        local enabled = r["tagops_" .. def.key] or false
        current_config["tagops_" .. def.key] = enabled
        if enabled then selected[def.key] = true end
    end
    saveGlobalConfig()

    local opts = {
        selected = selected,
        amount = r.tagops_amount,
        mode = r.tagops_mode,
        align_org = r.tagops_align_org,
        replace = r.tagops_replace,
        all_blocks = r.tagops_all_blocks,
        append = r.tagops_append,
        info = r.tagops_info,
    }
    local applied = false
    if b == L("btn_copy_tags") then
        applied = TagOps.opCopy(subs, sel, opts)
    elseif b == L("btn_keep_only") then
        applied = TagOps.opKeepOnly(subs, sel, opts)
    elseif r.tagops_action == "Resize / transform" then
        applied = TagOps.opAdjust(subs, sel, opts)
    elseif r.tagops_action == "Pos Align" then
        applied = TagOps.opPosAlign(subs, sel, opts)
    end
    return applied == true
end

config_gui = function()
    resolveConfig()
    local langItems, langMap, langShown = dropdownData({"en", "es", "pt"})
    local state = FunctionalTable.union(current_config, DEFAULT_CONFIG)
    local d = {
        {class="label", label=L("btn_config"), x=0, y=0, width=8, height=1},
        {class="label", label=L("lbl_language"), x=0, y=1, width=2, height=1},
        {class="dropdown", name="language", items=langItems, value=shownChoice(langShown, state.language), x=2, y=1, width=2, height=1},

        {class="label", label=sectionTitle("title_colorbar"), x=0, y=2, width=4, height=1},
        {class="label", label=L("lbl_mask"), x=0, y=3, width=1, height=1},
        {class="coloralpha", name="mask_color", value=state.mask_color, x=1, y=3, width=1, height=1},

        {class="label", label=L("btn_fastsigns"), x=0, y=4, width=8, height=1},
        {class="label", label=L("lbl_box"), x=0, y=5, width=1, height=1},
        {class="coloralpha", name="fastsign_box_color", value=state.fastsign_box_color, x=1, y=5, width=1, height=1},
        {class="label", label=L("lbl_text"), x=2, y=5, width=1, height=1},
        {class="coloralpha", name="fastsign_text_color", value=state.fastsign_text_color, x=3, y=5, width=1, height=1},
        {class="label", label=L("lbl_glow"), x=4, y=5, width=1, height=1},
        {class="coloralpha", name="fastsign_glow_color", value=state.fastsign_glow_color, x=5, y=5, width=1, height=1},

        {class="label", label=L("lbl_alpha"), x=0, y=6, width=2, height=1},
        {class="edit", name="fastsign_box_alpha", value=state.fastsign_box_alpha, x=2, y=6, width=2, height=1},
        {class="label", label=L("lbl_glow") .. " A", x=4, y=6, width=2, height=1},
        {class="edit", name="fastsign_glow_alpha", value=state.fastsign_glow_alpha, x=6, y=6, width=2, height=1},
        {class="label", label=L("lbl_fade"), x=8, y=6, width=2, height=1},
        {class="intedit", name="fastsign_fade_ms", value=state.fastsign_fade_ms, min=0, x=10, y=6, width=3, height=1},

        {class="label", label=L("lbl_pad_x"), x=0, y=7, width=2, height=1},
        {class="intedit", name="fastsign_margin_h", value=state.fastsign_margin_h, min=0, x=2, y=7, width=3, height=1},
        {class="label", label=L("lbl_pad_y"), x=5, y=7, width=2, height=1},
        {class="intedit", name="fastsign_margin_v", value=state.fastsign_margin_v, min=0, x=7, y=7, width=3, height=1},
        {class="label", label=L("lbl_top"), x=10, y=7, width=2, height=1},
        {class="intedit", name="fastsign_top_offset", value=state.fastsign_top_offset, min=0, x=12, y=7, width=3, height=1},

        {class="label", label=L("lbl_gap"), x=0, y=8, width=2, height=1},
        {class="intedit", name="fastsign_horz_gap", value=state.fastsign_horz_gap, min=0, x=2, y=8, width=3, height=1},
        {class="label", label=L("lbl_max_width"), x=5, y=8, width=2, height=1},
        {class="intedit", name="fastsign_max_width", value=state.fastsign_max_width, min=10, max=100, x=7, y=8, width=3, height=1},
        {class="label", label=L("lbl_box_blur"), x=10, y=8, width=3, height=1},
        {class="floatedit", name="fastsign_box_blur", value=state.fastsign_box_blur, min=0, x=13, y=8, width=3, height=1},

        {class="label", label=L("lbl_glow_border"), x=0, y=9, width=3, height=1},
        {class="floatedit", name="fastsign_glow_border", value=state.fastsign_glow_border, min=0, x=3, y=9, width=3, height=1},
        {class="label", label=L("lbl_glow_blur"), x=6, y=9, width=3, height=1},
        {class="floatedit", name="fastsign_glow_blur", value=state.fastsign_glow_blur, min=0, x=9, y=9, width=3, height=1},
        {class="label", label=L("lbl_text_blur"), x=0, y=10, width=3, height=1},
        {class="floatedit", name="fastsign_text_blur", value=state.fastsign_text_blur, min=0, x=3, y=10, width=3, height=1},
    }

    local b, r = aegisub.dialog.display(d, {L("btn_save"), L("btn_cancel")})
    if b ~= L("btn_save") then return false end
    r.language = rawChoice(langMap, r.language)
    for key in pairs(DEFAULT_CONFIG) do
        if r[key] ~= nil then current_config[key] = r[key] end
    end
    current_lang = current_config.language or current_lang
    saveGlobalConfig()
    return true
end

local function macroPath(name)
    if name == "" then return script_name end
    return script_name .. "/" .. name
end

local function hotkeyPath(name)
    return HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/" .. name
end

local function fastsigns_macro(subs, sel)
    return RheaOps.Tools.fastSigns(subs, sel)
end

local function signs_editor_macro(subs, sel)
    return RheaOps.Tools.massSigns(subs, sel)
end

local function integrated_tool_macro(name)
    return function(subs, sel)
        resolveConfig()
        if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end
        local tool = integratedTool(name)
        if tool then return tool.main(subs, sel, nil, integratedToolContext()) end
    end
end

local function fade_macro(action)
    return function(subs, sel)
        resolveConfig()
        if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end
        local tool = integratedTool("Fast Fades")
        if tool and type(tool.run) == "function" then
            return tool.run(subs, sel, action, integratedToolContext())
        end
    end
end

local function shapes_macro(action)
    return function(subs, sel, active)
        resolveConfig()
        if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end
        local cfg = SHAPE_CONFIG.read()
        local tool = integratedTool("Shapes")
        if not tool then return end
        return tool.main(subs, sel, active, {
            action = action,
            perimeter_mode = RheaFoundation.choose(cfg.perimeter_mode, {"Exterior contours only", "Exterior contours and holes"}, SHAPE_DEFAULTS.perimeter_mode),
            mode = RheaFoundation.choose(cfg.optimizer_mode, SharedShapeOptimizer.modes, SHAPE_DEFAULTS.optimizer_mode),
            intensity = RheaFoundation.choose(cfg.intensity, SharedShapeOptimizer.intensities, SHAPE_DEFAULTS.intensity),
            threshold = RheaFoundation.configNumber(cfg.threshold, SHAPE_DEFAULTS.threshold, 0, 0.25),
            max_bands = RheaFoundation.configNumber(cfg.max_bands, SHAPE_DEFAULTS.max_bands, 2, 64),
            show_summary = cfg.show_summary == true,
        }, integratedToolContext())
    end
end

depRec:registerMacros({
    { macroPath(""), script_description, row_master_gui },
    { hotkeyPath("TagOps"), "Tag operations", tagops_gui },
    { hotkeyPath("Fast Signs"), "Generate fast signs", fastsigns_macro },
    { hotkeyPath("Signs Editor"), "Edit repeated sign text", signs_editor_macro },
    { hotkeyPath("Shapes/Unify Positions"), "Unify ASS drawing pivots", shapes_macro("Unify Positions") },
    { hotkeyPath("Shapes/Place on Perimeter"), "Repeat multilayer shapes along a perimeter", shapes_macro("Place on Perimeter") },
    { hotkeyPath("Shapes/Shape Color Optimizer"), "Optimize drawing colors", shapes_macro("Shape Color Optimizer") },
    { hotkeyPath("Font and Style Manager"), "Manage fonts and styles", integrated_tool_macro("Font and Style Manager") },
    { hotkeyPath("Fast Fades"), "Open frame fades and continuous cleanup", integrated_tool_macro("Fast Fades") },
    { hotkeyPath("Fast Fades/In"), "Set fade in from the current frame", fade_macro("Fade In from Current Frame") },
    { hotkeyPath("Fast Fades/Out"), "Set fade out from the current frame", fade_macro("Fade Out from Current Frame") },
    { hotkeyPath("Fast Fades/Clean"), "Clean continuous fades", fade_macro("Continuous Fade Cleanup") },
    { hotkeyPath("Shuffle Line Text"), "Shuffle selected line text", integrated_tool_macro("Shuffle Line Text") },
}, false)
