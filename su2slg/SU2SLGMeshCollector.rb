class SU2SLGMeshCollector
FRONTF = "su2slg_front_face"

attr_reader :count_faces, :materials, :fm_materials

def initialize
@parent_mat=[]
@fm_comp=[]
@materials = {}
@fm_materials = {}
@count_faces = 0
end
#####################################################################
###### - collect entities to an array -						 		######
#####################################################################
def collect_faces(object, trans)

	if object.class == Sketchup::ComponentInstance
		entity_list=object.definition.entities
	elsif object.class == Sketchup::Group
		entity_list=object.entities
	else
		entity_list=object
	end

	p "entity count="+entity_list.count.to_s
	text=""
	text="Component: " + object.definition.name if object.class == Sketchup::ComponentInstance
	text="Group" if object.class == Sketchup::Group
	
	Sketchup.set_status_text "Collecting Faces - Level #{@parent_mat.size} - #{text}"

	for e in entity_list
	  
		if (e.class == Sketchup::Group and e.layer.visible?)
			get_inside(e,trans,false) #e,trans,false - not FM component
		end
		if (e.class == Sketchup::ComponentInstance and e.layer.visible? and e.visible?)
			get_inside(e,trans,e.definition.behavior.always_face_camera?) # e,trans, fm_component?
		end
		if (e.class == Sketchup::Face and e.layer.visible? and e.visible?)
			face_properties=find_face_material(e)
			mat=face_properties[0]
			uvHelp=face_properties[1]
			mat_dir=face_properties[2]

			if @fm_comp.last==true
				(@fm_materials[mat] ||= []) << [e,trans,uvHelp,mat_dir]
			else
				(@materials[mat] ||= []) << [e,trans,uvHelp,mat_dir] #if (@animation==false or (@animation and @export_full_frame))
			end
			@count_faces+=1
		end
	end
end

#####################################################################
# private method
#####################################################################
def find_face_material(e)
	mat = Sketchup.active_model.materials[FRONTF]
	mat = Sketchup.active_model.materials.add FRONTF if mat.nil?
	front_color = Sketchup.active_model.rendering_options["FaceFrontColor"]
	scale = 0.8 / 255.0
	mat.color = Sketchup::Color.new(front_color.red * scale, front_color.green * scale, front_color.blue * scale)
	uvHelp=nil
	mat_dir=true
	if e.material!=nil
		mat=e.material
	else
		if e.back_material!=nil
			mat=e.back_material
			mat_dir=false
		else
			mat=@parent_mat.last if @parent_mat.last!=nil
		end
	end

	# if (mat.respond_to?(:texture) and mat.texture !=nil)
		# ret=SU2KT.store_textured_entities(e,mat,mat_dir)
		# mat=ret[0]
		# uvHelp=ret[1]
	# end

	return [mat,uvHelp,mat_dir]
end
  
  
#####################################################################
# private method
#####################################################################
def get_inside(e,trans,face_me)
	@fm_comp.push(face_me)
	if e.material != nil
		mat = e.material
		@parent_mat.push(e.material)
		#SU2KT.store_textured_entities(e,mat,true) if (mat.respond_to?(:texture) and mat.texture!=nil)
	else
		@parent_mat.push(@parent_mat.last)
	end
	collect_faces(e, trans*e.transformation)
	@parent_mat.pop
	@fm_comp.pop
end

end

