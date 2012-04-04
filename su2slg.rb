require 'sketchup.rb'

module SU2SLG
CONFIG_FILE = "slg_path.txt"
SCENE_NAME='tmpscene.scn'
EXT_SCENE = ".scn"

def SU2SLG.render
	SU2SLG.reset_variables
	p @slg_path
	model = Sketchup.active_model
    model_filename = File.basename(model.path)
    if model_filename.empty?
      export_filename = SCENE_NAME
    else
      dot_position = model_filename.rindex(".")
      export_filename = model_filename.slice(0..(dot_position - 1))
      export_filename += EXT_SCENE
    end
	
	export_folder=SU2SLG.find_default_folder
	#export_folder=export_folder+@os_separator+'testscene'
	#@export_file_path=UI.savepanel("Select empty folder where save export files",export_folder,export_filename)
	@export_file_path=File.dirname(@slg_path)+"/scenes/tmpscene/"+export_filename
	
	@cfg_file_path=File.dirname(@export_file_path) + @os_separator + 'render.cfg'
	
	p 'export file path '+@export_file_path
	p 'cfg file path'+ @cfg_file_path
	
	#TODO: export ply
	mc=SU2SLGMeshCollector.new
	mc.collect_faces(Sketchup.active_model.entities, Geom::Transformation.new)
	@materials=mc.materials
	@fm_materials=mc.fm_materials
	@count_faces=mc.count_faces
	@current_mat_step = 1
	#@materials.inspect
	
	SU2SLG.write_scene_file
	SU2SLG.write_render_cfg
	
	SU2SLG.launch_slg
end

def SU2SLG.point_to_vector(p)
	Geom::Vector3d.new(p.x,p.y,p.z)
end


def SU2SLG.export_face(mat,fm_mat)
	ply_path=File.dirname(@export_file_path) + @os_separator + mat.display_name+'.ply'
	#ply_path="scenes/testscene/" + mat.display_name+".ply"
	
	ply_file=File.new(ply_path,"w")
	ply_file << "ply\n"
	ply_file << "format ascii 1.0\n"
	ply_file << "comment created by SU2SLG " << Time.new << "\n"


	meshes = []
	polycount = 0
	pointcount = 0
	mirrored=[]
	mat_dir=[]
	default_mat=[]
	distorted_uv=[]
	
	if fm_mat
		export=@fm_materials[mat]
	else
		export=@materials[mat]
	end

	has_texture = false
	if mat.respond_to?(:name)
		matname = mat.display_name.gsub(/[<>]/,'*')
		# has_texture = true if mat.texture!=nil
	else
		matname = "Default"
		# has_texture=true if matname!=FRONTF
	 end
	
	matname="FM_"+matname if fm_mat
	

		
	#Introduced by SJ
	total_mat = @materials.length + @fm_materials.length
	mat_step = " [" + @current_mat_step.to_s + "/" + total_mat.to_s + "]"
	@current_mat_step += 1

	total_step = 4
	if (has_texture and @clay==false) or @exp_default_uvs==true
		total_step += 1
	end
	current_step = 1
	rest = export.length*total_step
	Sketchup.set_status_text("Converting Faces to Meshes: " + matname + mat_step + "...[" + current_step.to_s + "/" + total_step.to_s + "]" + " #{rest}")
	#####
	
	
	for ft in export
		Sketchup.set_status_text("Converting Faces to Meshes: " + matname + mat_step + "...[" + current_step.to_s + "/" + total_step.to_s + "]" + " #{rest}") if (rest%500==0)
		rest-=1
	
	  	polymesh=(ft[3]==true) ? ft[0].mesh(5) : ft[0].mesh(6)
		trans = ft[1]
		trans_inverse = trans.inverse
		default_mat.push (ft[0].material==nil)
		distorted_uv.push ft[2]
		mat_dir.push ft[3]

		polymesh.transform! trans
	  
	 
		xa = SU2SLG.point_to_vector(ft[1].xaxis)
		ya = SU2SLG.point_to_vector(ft[1].yaxis)
		za = SU2SLG.point_to_vector(ft[1].zaxis)
		xy = xa.cross(ya)
		xz = xa.cross(za)
		yz = ya.cross(za)
		mirrored_tmp = true
	  
		if xy.dot(za) < 0
			mirrored_tmp = !mirrored_tmp
		end
		if xz.dot(ya) < 0
			mirrored_tmp = !mirrored_tmp
		end
		if yz.dot(xa) < 0
			mirrored_tmp = !mirrored_tmp
		end
		mirrored << mirrored_tmp

		meshes << polymesh
		@count_faces-=1

		polycount=polycount + polymesh.count_polygons
		pointcount=pointcount + polymesh.count_points
	end
	
	ply_file << "element vertex #{pointcount}\n"
	ply_file << "property float x\n"
	ply_file << "property float y\n"
	ply_file << "property float z\n"
	ply_file << "element face #{polycount}\n"
	#ply_file << "property list uint8 int32\n" 
	ply_file << "property list uchar uint vertex_indices\n"
	ply_file << "end_header\n"

	startindex = 0
	
	# Exporting vertices
	#has_texture = false
	current_step += 1
	
	
	#out.puts 'AttributeBegin'
	i=0
	
	#luxrender_mat=LuxrenderMaterial.new(mat)
	#Exporting faces indices
	#light
	# LightGroup "default"
	# AreaLightSource "area" "texture L" ["material_name:light:L"]
   # "float power" [100.000000]
   # "float efficacy" [17.000000]
   # "float gain" [1.000000]
	
	# case luxrender_mat.type
		# when "matte", "glass"
			# out.puts "NamedMaterial \""+luxrender_mat.name+"\""
		# when "light"
			# out.puts "LightGroup \"default\""
			# out.puts "AreaLightSource \"area\" \"texture L\" [\""+luxrender_mat.name+":light:L\"]"
			# out.puts '"float power" [100.000000]
			# "float efficacy" [17.000000]
			# "float gain" [1.000000]'
	# end
	
	#out.puts 'Shape "trianglemesh" "integer indices" ['
	#Exporting verticies  points
	#out.puts '"point P" ['
	for mesh in meshes
		for p in (1..mesh.count_points)
			pos = mesh.point_at(p).to_a
			#out.print "#{"%.6f" %(pos[0]*@scale)} #{"%.6f" %(pos[1]*@scale)} #{"%.6f" %(pos[2]*@scale)}\n"
			ply_file << "#{"%.6f" %(pos[0]*@scale)} #{"%.6f" %(pos[1]*@scale)} #{"%.6f" %(pos[2]*@scale)}\n"		
		end
	end
	#out.puts ']'
	
	
	
	for mesh in meshes
	  	mirrored_tmp = mirrored[i]
		mat_dir_tmp = mat_dir[i]
		for poly in mesh.polygons
			v1 = (poly[0]>=0?poly[0]:-poly[0])+startindex
			v2 = (poly[1]>=0?poly[1]:-poly[1])+startindex
			v3 = (poly[2]>=0?poly[2]:-poly[2])+startindex
			#out.print "#{v1-1} #{v2-1} #{v3-1}\n"
			if !mirrored_tmp
				if mat_dir_tmp==true
					#out.print "#{v1-1} #{v2-1} #{v3-1}\n"
					ply_file << "3 #{v1-1} #{v2-1} #{v3-1}\n"
				else
					#out.print "#{v1-1} #{v3-1} #{v2-1}\n"
					ply_file << "3 #{v1-1} #{v3-1} #{v2-1}\n"
				end
			else
				if mat_dir_tmp==true
					#out.print "#{v2-1} #{v1-1} #{v3-1}\n"
					ply_file << "3 #{v2-1} #{v1-1} #{v3-1}\n"
				else
					#out.print "#{v2-1} #{v3-1} #{v1-1}\n"
					ply_file << "3 #{v2-1} #{v3-1} #{v1-1}\n"
				end
			end		
		
		@count_tri = @count_tri + 1
	  end
	  startindex = startindex + mesh.count_points
	  i+=1
	end
	#out.puts ']'
	
	
	# i=0
	# #Exporting normals
	# out.puts '"normal N" ['
	# for mesh in meshes
		# Sketchup.set_status_text("Material being exported: " + matname + mat_step + "...[" + current_step.to_s + "/" + total_step.to_s + "]" + " - Normals " + " #{rest}") if rest%500==0
		# rest -= 1
		# mat_dir_tmp = mat_dir[i]
		# for p in (1..mesh.count_points)
			# norm = mesh.normal_at(p)
			# norm.reverse! if mat_dir_tmp==false
				# out.print " #{"%.4f" %(norm.x)} #{"%.4f" %(norm.y)} #{"%.4f" %(norm.z)}\n"
		# end
		# i += 1
	# end
ply_file.close
return ply_path
end


def SU2SLG.export_camera(view)
	
	lookat=''
	user_camera = view.camera
	user_eye = user_camera.eye
	#p user_eye
	user_target=user_camera.target
	#p user_target
	user_up=user_camera.up
	#p user_up;
	out_user_target = "%12.6f" %(user_target.x.to_m.to_f) + " " + "%12.6f" %(user_target.y.to_m.to_f) + " " + "%12.6f" %(user_target.z.to_m.to_f)

	#out_user_up = "%12.6f" %(user_up.x) + " " + "%12.6f" %(user_up.y) + " " + "%12.6f" %(user_up.z)

	#out.puts "LookAt"
	lookat="%12.6f" %(user_eye.x.to_m.to_f) + " " + "%12.6f" %(user_eye.y.to_m.to_f) + " " + "%12.6f" %(user_eye.z.to_m.to_f)+" "+out_user_target
	# out_user_target
	# out.puts out_user_up
	# out.print "\n"
	return lookat
end


#####################################################################
#####################################################################
def SU2SLG.find_default_folder
	folder=File.dirname(@slg_path) + @os_separator + "scenes"+@os_separator+"tmpscene"
	if File.exists?(folder) && File.directory?(folder)
		p 'dir tmpscene exist'
	else
		Dir.mkdir(folder)
	end
	#folder = ENV["USERPROFILE"]
	#folder = File.expand_path("~") if on_mac?
	return folder
end

def SU2SLG.write_scene_file

	view=Sketchup.active_model.active_view
	lookat=SU2SLG.export_camera(view)
	scene_file=File.new(@export_file_path,"w")
	scene_file <<  "scene.camera.lookat = #{lookat}\n"
	
	@materials.each{|mat,value|
		if (value!=nil and value!=[])
			SU2SLG.export_face(mat,false)
			ply_path="scenes/tmpscene/" + mat.display_name+".ply"
			if mat.display_name.scan("light").size>0 
			mattype="light"
			else
			mattype="matte"
			end
			scene_file << "scene.materials.#{mattype}."<<mat.display_name<<" = "<<"#{"%.6f" %(mat.color.red.to_f/255)} #{"%.6f" %(mat.color.green.to_f/255)} #{"%.6f" %(mat.color.blue.to_f/255)}"<<"\n"
			scene_file << "scene.objects."<<mat.display_name<<"."<<mat.display_name<<" = "<< ply_path<<"\n"
			@materials[mat]=nil
		end}
	@materials={}
	
	scene_file.close

	bat_file=File.dirname(@export_file_path) + @os_separator + 'start.bat'
	bat_file=File.new(bat_file,"w")
	bat_file << "@echo off\n"
	bat_file << "CD ..\n"
	bat_file << "CD ..\n"
	#bat_file << @slg_path<< " \"" << @cfg_file_path << "\"\n"
	bat_file << "SLG.exe"<< " \"" << @cfg_file_path << "\"\n"
	bat_file << "pause"
	bat_file.close
	# @echo off
	# SLG.exe scenes\cat\render-fast.cfg
	# pause
	

end


#####################################################################
#####################################################################
def SU2SLG.launch_slg
	# @luxrender_path = SU2LUX.get_luxrender_path if @luxrender_path.nil?
	# return if @luxrender_path.nil?
	Dir.chdir(File.dirname(@slg_path))
	cfg_path = "#{@cfg_file_path}"
	cfg_path = File.join(cfg_path.split(@os_separator))
	if (ENV['OS'] =~ /windows/i)
	 command_line = "start \"max\" \"#{@slg_path}\" \"#{cfg_path}\""
	 puts command_line
	 system(command_line)
	 else
		Thread.new do
			system(`#{@slg_path} "#{cfg_path}"`)
		end
	end
end





def SU2SLG.write_render_cfg
			render_cfg = File.new(@cfg_file_path, "w")
			render_cfg.puts 'image.width = 640
image.height = 480
# Use a value > 0 to enable batch mode
batch.halttime = 0'
render_cfg << "scene.file = #{@export_file_path}\n"
#scene.file = scenes/kitchen/kitchen.scn
#scene.file = c:\Documents and Settings\Administrator\testscene\cat.scn

render_cfg.puts 'scene.fieldofview = 90
opencl.latency.mode = 0
opencl.nativethread.count = 2
opencl.cpu.use = 0
opencl.gpu.use = 1
# Select the OpenCL platform to use (0=first platform available, 1=second, etc.)
opencl.platform.index = 0
# The string select the OpenCL devices to use (i.e. first "0" disable the first
# device, second "1" enable the second).
#opencl.devices.select = 10
# This value select the number of threads to use for keeping
# each OpenCL devices busy
#opencl.renderthread.count = 4
# Use a value of 0 to enable default value
opencl.gpu.workgroup.size = 64
screen.refresh.interval = 100
# Select the Film type:
#  0 => Standard Film version
#  1 => New Film with blured preview
#  2 => New Film with Gaussian filter
#  3 => New Film with Gaussian filter with fast preview
screen.type = 3
path.maxdepth = 3
path.russianroulette.depth = 2
path.russianroulette.prob = 0.75
# 0 = ONE_UNIFORM strategy
# 1 = ALL_UNIFORM strategy
path.lightstrategy = 0
path.shadowrays = 1
'
			render_cfg.close
end

#####################################################################
#####################################################################
def SU2SLG.on_mac?
	return (Object::RUBY_PLATFORM =~ /mswin/i) ? FALSE : ((Object::RUBY_PLATFORM =~ /darwin/i) ? TRUE : :other)
end


def SU2SLG.initialize_variables
  @slg_path = "" #needs to go with luxrender settings
  
  if on_mac? #group the mac initializations together: making porting easier
    @os_separator = "/" 
    @slg_filename = "Luxrender.app/Contents/MacOS/Luxrender"
    #there are probably more
  else if not on_mac?
    @slg_filename = "SLG.exe"
    @os_separator = "\\"
  end
end
end


def SU2SLG.get_slg_path
	find_slg = true
	# path = ENV['LUXRENDER_ROOT']
	# if ( ! path.nil?)
		# luxrender_path = path + @os_separator + @luxrender_filename
		# if (File.exists?(luxrender_path))
			# find_luxrender = false
		# end
	# end
	
	if (find_slg == true)
		path=File.dirname(__FILE__) + @os_separator + CONFIG_FILE
		p path
		if File.exist?(path)
			path_file = File.open(path, "r")
			slg_path = path_file.read
			path_file.close
			find_slg = false
		end
	end
	
	# mac_path = SU2LUX.search_mac_luxrender
	# if ( ! mac_path.nil?)
		# luxrender_path = mac_path + @os_separator + @luxrender_filename
		# if (SU2LUX.luxrender_path_valid?(luxrender_path))
			# path=File.dirname(__FILE__) + @os_separator + CONFIG_FILE
			# path_file = File.new(path, "w")
			# path_file.write(luxrender_path)
			# path_file.close
			# find_luxrender = false
		# end
	# end
	
	if (find_slg == true)
		slg_path = UI.openpanel("Locate SLG.exe", "", "")
		return nil if slg_path.nil?
		if (slg_path && SU2SLG.slg_path_valid?(slg_path))
			path=File.dirname(__FILE__) + @os_separator + CONFIG_FILE
			path_file = File.new(path, "w")
			path_file.write(slg_path)
			path_file.close
		end
	end
	if SU2SLG.slg_path_valid?(slg_path)
	  return slg_path
	else
	  return nil
	end 
end

def SU2SLG.slg_path_valid?(slg_path)
	(! slg_path.nil? and File.exist?(slg_path) and (File.basename(slg_path).upcase.include?("SLG")))
	#check if the path to Luxrender is valid
end


def SU2SLG.reset_variables
	@materials = {}
	@fm_materials = {}
	@count_faces = 0
	@clay=false
	@exp_default_uvs = false
	@scale = 0.0254
	@count_tri = 0
	# @n_pointlights=0
	# @n_spotlights=0
	# @n_cameras=0
	# @face=0
	# @copy_textures = true
	# @export_materials = true
	# @export_meshes = true
	# @export_lights = true
	# @instanced=true
	# @model_name=""
	# @textures_prefix = "TX_"
	# @texturewriter=Sketchup.create_texture_writer
	# @model_textures={}
	# @lights = []
	# @components = {}
	# @selected=false
	# @exp_distorted = false
	# @animation=false
	# @export_full_frame=false
	# @frame=0
	# @status_prefix = ""   # Identifies which scene is being processed in status bar
	# @scene_export = false # True when exporting a model for each scene
	# @status_prefix=""
	@scale = 0.0254
	@slg_path = SU2SLG.get_slg_path
	#@used_materials = []
end

#####################################################################
#####################################################################
def SU2SLG.about
UI.messagebox("SU2SLG development version for SLG 1.4beta3 28th March 2010
SketchUp Exporter to SmallLuxGPU
Authors: Alexander Smirnov (aka Exvion)
E-mail: exvion@gmail.com 

For further information please visit
Luxrender Website & Forum - www.luxrender.net" , MB_MULTILINE , "SU2SLG - Sketchup Exporter to SmallLuxGPU")
end



end

if( not file_loaded?(__FILE__) )
	SU2SLG.initialize_variables

	main_menu = UI.menu("Plugins").add_submenu("SmallLuxGPU")
	main_menu.add_item('Render and export to folder') { (SU2SLG.render)}
	#main_menu.add_item("Export Copy") {(SU2LUX.export_copy)}
	#main_menu.add_item("Settings") { (SU2LUX.show_settings_editor)}
	#main_menu.add_item("Material Editor") {(SU2LUX.show_material_editor)}
	main_menu.add_item("About") {(SU2SLG.about)}
	load File.join("su2slg","SU2SLGMeshCollector.rb")
	#load File.join("su2slg","SLGExport.rb")
end


file_loaded(__FILE__)
