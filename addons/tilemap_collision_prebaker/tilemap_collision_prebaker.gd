@tool
extends Node2D

class_name TileMapCollisionPreBaker

## This script is used for pre-baking the collisions of the tilemap to prevent some unexpected bugs like
## RigidBody2D gets stuck when it is moving on the tile floor.
##
## Change the value of bake to bake colliders.It will bake all the layers and physics layers 
## of the target tilemap.


## TileMap for baking collision
@export var target_tilemap:NodePath

## Delete all children before baking
@export var delete_children_before_bake:bool=true

@export var sync_collision_layer_mask:bool=true

## Pseudo property. It's actually a button, click to bake TileMap
@export var bake:bool=false:
	set(new):
		bake_colliders()


## Bake TileMap
func bake_colliders() -> void:
	if not has_node(target_tilemap):
		print("Target tilemap is missing")
		return
	
	if delete_children_before_bake:
		delete_children()
	
	# Bake Layers
	var tilemap=get_node(target_tilemap) as TileMap
	for layer in range(tilemap.get_layers_count()):
		bake_layer_colliders(tilemap,layer)
	print("Baking completed")


## Bake a layer of the tilemap
func bake_layer_colliders(tilemap:TileMap,layer:int) -> void:
	var tile_set:=tilemap.tile_set
	var node=Node2D.new()
	add_child(node)
	
	var layer_name=tilemap.get_layer_name(layer)
	if layer_name.is_empty():
		layer_name="Layer%d"%layer
	node.name=layer_name
	node.owner=owner
	
	for physics_layer in range(tile_set.get_physics_layers_count()):
		bake_physics_layer_colliders(tilemap,layer,physics_layer,node)
	print("Layer%d baked"%layer)


## Bake a physics layer of a layer of the tilemap
func bake_physics_layer_colliders(tilemap:TileMap,layer:int,physics_layer:int,layer_node:Node2D) -> void:
	var tile_set=tilemap.tile_set
	var polygons:=get_polygons(tilemap,layer,physics_layer)	
	var merged_polygons:=merge_polygons(polygons)
	var node=StaticBody2D.new()
	layer_node.add_child(node)
	node.name="PhysicsLayer%d"%physics_layer
	node.owner=owner
	if sync_collision_layer_mask:
		node.collision_layer=tile_set.get_physics_layer_collision_layer(physics_layer)
		node.collision_mask=tile_set.get_physics_layer_collision_mask(physics_layer)
	node.physics_material_override=tile_set.get_physics_layer_physics_material(physics_layer)
	
	for polygon in merged_polygons:
		var coll=CollisionPolygon2D.new()
		coll.polygon=polygon
		node.add_child(coll,true)
		coll.owner=layer_node.owner
	print("PhysicsLayer%d in Layer%d baked"%[physics_layer,layer])


## Get all the collision polygons of a physics layer in a layer of the tilemap
func get_polygons(tilemap:TileMap,layer:int,physics_layer:int) -> Array[PackedVector2Array]:
	var polygons:Array[PackedVector2Array]=[]
	var tile_set:=tilemap.tile_set
	var tile_size:=tile_set.tile_size
	var used_cells=tilemap.get_used_cells(layer)
	for cell in used_cells:
		var source=tile_set.get_source(tilemap.get_cell_source_id(layer,cell))
		if source is TileSetAtlasSource:
			var data=source.get_tile_data(tilemap.get_cell_atlas_coords(layer,cell),tilemap.get_cell_alternative_tile(layer,cell)) as TileData
			for index in range(data.get_collision_polygons_count(physics_layer)):
				polygons.append(move_polygon(data.get_collision_polygon_points(physics_layer,index),cell*tile_size+tile_size/2))
	return polygons


## This function iterates through each polygon in the polygons array and attempts to merge it with the remaining polygons in the array.  
## If a mergeable polygon is found, they are merged and replace the original polygon; if not, the polygon is added to the merged_polygons array.  
## This process repeats until the polygons array is empty, at which point the merged_polygons array containing all merged polygons is returned.
func merge_polygons(polygons:Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var merged_polygons:Array[PackedVector2Array]=[]
	while(not polygons.is_empty()):
		var mergeing_pol:=polygons.pop_back() as PackedVector2Array
		var index=polygons.size()-1
		var merged:bool=false
		while(index>=0):
			var being_merged_pol:=polygons[index] as PackedVector2Array
			var mergers=Geometry2D.merge_polygons(mergeing_pol,being_merged_pol)
			if mergers.size()==1:
				polygons.remove_at(index)
				polygons.append(mergers[0])
				merged=true
				break
			index-=1
		if not merged:
			merged_polygons.append(mergeing_pol)
	return merged_polygons


## Delete all the children
func delete_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


## Move the polygon by a Vector2
func move_polygon(polygon:PackedVector2Array,move:Vector2) -> PackedVector2Array:
	var arr:PackedVector2Array=[]
	for point in polygon:
		arr.append(point+move)
	return arr
