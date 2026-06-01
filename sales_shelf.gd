# ShopSalesShelf.gd — étagère fixe dans la ShopScene (non-constructible)
extends Building
class_name ShopSalesShelf

@export var storage_slots: int = 10
@export var size_override: Vector2i = Vector2i.ZERO   # (0,0) => garde taille DB
@export var world_texture: Texture2D                   # optionnel
@export var storage_ui_scene: PackedScene              # optionnel

const DEF_BASE := {
	"id": "sales_shelf_shop",
	"name": "Étagère de vente",
	"description": "Expose des produits à la vente.",
	"tier": 1,
	"type": BuildingDatabase.BuildingType.STORAGE,
	"size": Vector2i(2, 1),
	"properties": {
		"is_sales_shelf": true,
		"storage_slots": 10  # sera override
	}
}

func _ready() -> void:
	if building_id.is_empty():
		var def := DEF_BASE.duplicate(true)
		def["properties"]["storage_slots"] = int(storage_slots)

		if size_override.x > 0 and size_override.y > 0:
			def["size"] = size_override

		if world_texture:
			def["properties"]["world_sprite"] = world_texture

		initialize(def, global_position, false)

	if not is_in_group("storage_buildings"):
		add_to_group("storage_buildings")

	# --- inventory component ---
	var comp: InventoryComponent = get_node_or_null("InventoryComponent") as InventoryComponent
	if comp == null:
		comp = get_node_or_null("Components/InventoryComponent") as InventoryComponent

	if comp != null:
		# ✅ ID STABLE (sinon HouseController génère storage:<instance_id> => casse au changement de scène)
		# On garde "storage:shop" (conforme à ton SalesManager v7 et tes logs).
		if String(comp.inventory_id) != "storage:shop":
			comp.inventory_id = "storage:shop"

		# Align soft: ne détruit rien (HouseController fera l'exact après)
		var wanted_slots = max(1, int(storage_slots))
		if comp.slot_count != wanted_slots:
			if comp.has_method("resize_slots_non_destructive"):
				comp.resize_slots_non_destructive(wanted_slots)
			else:
				comp.slot_count = wanted_slots

		# ✅ sales perish control
		comp.sales_perish_control_enabled = true
		comp.sales_front_row_size = int(max(0, wanted_slots / 2))

		# Optionnel : appliquer une première fois (si GameClock pas prêt, le retry interne fera le reste)
		if comp.has_method("_apply_sales_perish_rules_for_slot"):
			for i in range(comp.slot_count):
				comp._apply_sales_perish_rules_for_slot(i)

	if EventBus:
		EventBus.log_debug(
			"[ShopSalesShelf] Ready inv=%s slots=%d (front=%d)"
			% [
				(String(comp.inventory_id) if comp != null else "<no_comp>"),
				(int(comp.slot_count) if comp != null else int(storage_slots)),
				(int(comp.sales_front_row_size) if comp != null else int(storage_slots / 2))
			],
			"SALES"
		)



func _apply_world_visual(_def: Dictionary) -> void:
	_sprite_base_scale = Vector2.ONE
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	# On garde le visuel de scène, ne rien toucher ici.


# ============================================================
# ================ PREVIEW (construction) ====================
# ============================================================
func set_preview_mode(enabled: bool) -> void:
	_is_preview = enabled
	if self is CanvasItem:
		(self as CanvasItem).modulate.a = (0.6 if enabled else 1.0)
	if collision_shape:
		collision_shape.disabled = enabled


func apply_tier(tier: int) -> void:
	var target_slots := 6
	match tier:
		1:
			target_slots = 6
		2:
			target_slots = 10
		_:
			target_slots = 10

	storage_slots = target_slots

	var comp: InventoryComponent = get_node_or_null("InventoryComponent") as InventoryComponent
	if comp == null:
		comp = get_node_or_null("Components/InventoryComponent") as InventoryComponent

	if comp != null:
		# ✅ ID STABLE
		if String(comp.inventory_id) != "storage:shop":
			comp.inventory_id = "storage:shop"

		# Resize non destructif
		if comp.has_method("resize_slots_non_destructive"):
			comp.resize_slots_non_destructive(target_slots)
		else:
			comp.slot_count = target_slots

		# ✅ sales perish control align
		comp.sales_perish_control_enabled = true
		comp.sales_front_row_size = int(target_slots / 2)

		if comp.has_method("_apply_sales_perish_rules_for_slot"):
			for i in range(comp.slot_count):
				comp._apply_sales_perish_rules_for_slot(i)

		# Notify systems/UI
		if EventBus and EventBus.has_signal("inventory_changed"):
			EventBus.inventory_changed.emit(String(comp.inventory_id))

	if EventBus:
		EventBus.log_debug(
			"[ShopSalesShelf] Tier %d applied → %d slots (inv=%s)"
			% [
				tier,
				target_slots,
				(String(comp.inventory_id) if comp != null else "<no_comp>")
			],
			"SALES"
		)
