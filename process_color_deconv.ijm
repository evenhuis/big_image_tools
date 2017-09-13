var slash=File.separator;  // Stupid windows!

var nred=4, ncol=4;

var othresh=190, ofact=0.9;
var	gthresh=190, gfact=0.9;
var	bthresh=190, bfact=0.9;

var sizeX0, sizeY0;
var dx_i, dy_i;
var dxr_i, dyr_i,dxr,dyr;
var  alphabet=newArray("A","B","C","D","E","F","G","H","I","J");


//quantify_whole_image();
quantify_sub_images();

//id=getImageID();
//cfact = get_white_balance_factors(id);
//Array.print(cfact);
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function get_white_balance_factors(id){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	selectImage(id);

	
	batch_on =is("Batch Mode");
	if( ! batch_on){setBatchMode(true);}
	run("Select All");
	run("Duplicate...","grey"); id_grey=getImageID();
	run("8-bit");
	roiManager("reset");
	
	outline_section(id_grey,othresh,1.00);
	
	
	selectImage(id);
	run("Select All");
	run("Duplicate...","rgb stack"); id_rgb=getImageID();	
	run("RGB Stack");
	
	cfactors=newArray(3);
	for(i=1;i<=3;i++){
		setSlice(i);
		getHistogram(values, counts, 256); 
		counts[0]=0;
		maxLocs= Array.findMaxima(counts, 20);
		cfactors[i-1]=maxLocs[0];
	}
	cnorm=(cfactors[0]+cfactors[1]+cfactors[2])/3.;
	cfactors[0]=cnorm/cfactors[0];
	cfactors[1]=cnorm/cfactors[1];
	cfactors[2]=cnorm/cfactors[2];

	selectImage(id_rgb);
	close();
	if( ! batch_on){setBatchMode(false);}

	return cfactors;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function set_white_balance(id, cfactors ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	selectImage(id);
	batch_on =is("Batch Mode");
	if( ! batch_on){setBatchMode(true);}
	run("RGB Stack");
	for(i=1;i<=3;i++){
		setSlice(i);
		run("Multiply...", "value="+cfactors[i-1]+" slice");
	}
	run("RGB Color");
	if( ! batch_on){ setBatchMode(false);}
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function quantify_whole_image(){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


	tmp=setup_file(false);
	filepath = tmp[1];
	path     = tmp[2];
	name     = tmp[3];
	setup_coordinates(filepath);

	bio_options   ="color_mode=Composite concatenate_series crop  view=Hyperstack stack_order=XYCZT ";
	coord_optsions="x_coordinate_1=0 y_coordinate_1=0"+sizeX0+" height_1="+sizeY0;
	run("Bio-Formats Importer", "open=["+filepath+"]" + bio_options );
	id_tmp = getImageID();
	run("RGB Color");
	id_stack=getImageID();
	selectImage(id_tmp); close();
	
	selectImage(id_stack);
	run("Add Slice"); //grey
	run("Add Slice"); // corrected
	run("Add Slice"); //brown

	setBatchMode(true);
	// get the outline mask
	selectImage(id_stack); setSlice(1);
	run("Select All");
	run("Duplicate...","grey"); id_grey=getImageID();
	run("8-bit");
	
	selectImage(id_grey);
	run("Select All"); run("Copy");
	selectImage(id_stack); setSlice(2);
	run("Paste");


	selectImage(id_stack); setSlice(1);
	run("Select All");
	run("Duplicate...","corrected"); id_cor=getImageID();
	rgb_factors = get_white_balance_factors(id_cor);
	print("RGB factors");
	Array.print(rgb_factors);

	set_white_balance(id_cor, rgb_factors );
	selectImage(id_cor);
	run("Select All"); run("Copy");
	selectImage(id_stack); setSlice(3);
	run("Paste");	

	roiManager("reset");
	//setBatchMode(true);
	
	outline_section(id_grey,othresh*0.975,0.975);
	outline_section(id_grey,othresh,1.000);
	outline_section(id_grey,othresh*1.025,1.025);
	

	run("Clear Results");
	setResult("id",0,"Summed");

	selectImage(id_stack); setSlice(1);
	thresh_labels=newArray("Total_lo","Total_mid","Total_hi");
	thresh_colors=newArray("blue","green","red");
	for(k=0;k<3;k++){

		roiManager("select", k);
		Roi.getCoordinates(out_x, out_y);
		makeSelection("freehand",out_x,out_y);
		getStatistics(area, mean, min, max, std, histogram);
		setResult(thresh_labels[k],0 ,area);

		
		makeSelection("freehand",out_x,out_y);
		Overlay.addSelection(thresh_colors[k]);
		Overlay.show();
	}
	
	roiManager("select", 1);
	Roi.getCoordinates(out_x, out_y);


	stats = perform_area_calc(id_grey, out_x, out_y, gthresh); 
	setResult("Grey_fill_lo", 0,stats[0]);
	setResult("Grey_fill_mid",0,stats[1]);
	setResult("Grey_fill_hi", 0,stats[2]);

	cids=split_color(id_cor);
	selectImage(cids[0]);close();
	selectImage(cids[2]);close();
	stats = perform_area_calc(cids[1], out_x, out_y, bthresh); 
	setResult("Brown_fill_lo", 0,stats[0]);
	setResult("Brown_fill_mid",0,stats[1]);
	setResult("Brown_fill_hi", 0,stats[2]);

	selectImage(cids[1]); 
	run("Select All"); run("Copy"); close();
	selectImage(id_stack); setSlice(4); run("Paste");
	
	setBatchMode(false);
	save(path+slash+name+"_full.tif");
	saveAs("Results",path+slash+name+"_full.area.txt");
	
	return;
}	

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function quantify_sub_images(){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	tmp=setup_file(true);
	id_red   = tmp[0];
	filepath = tmp[1];
	path     = tmp[2];
	name     = tmp[3];

	roiManager("reset")
	run("Select All");
	roiManager("add");
	roiManager("reset")
	setBatchMode(true);

	// get the outline mask
	selectImage(id_red);
	run("Select All");
	run("Duplicate...","grey"); id_grey=getImageID();
	run("8-bit");

	// set the othresh
	getHistogram(values, counts, 256);
	for(k=0;k<100;k++){
		counts[k]=0;
	}
	maxlocs=Array.findMaxima(counts,10);
	othresh=ofact*maxlocs[0];
	gthresh=gfact*maxlocs[0];
	bthresh=bfact*maxlocs[0];
	
	selectImage(id_grey);
	run("Select All"); run("Copy");
	selectImage(id_red); 
	setSlice(2);
	run("Paste");
	

	selectImage(id_red); setSlice(1);
	run("Select All");
	run("Duplicate...","corrected"); id_cor=getImageID();
	rgb_factors = get_white_balance_factors(id_cor);
	print("RGB factors");
	Array.print(rgb_factors);

	set_white_balance(id_cor, rgb_factors );
	selectImage(id_cor);
	run("Select All"); run("Copy");
	selectImage(id_red); setSlice(3);
	run("Paste");
	
	roiManager("reset");
	//setBatchMode(true);
	outline_section(id_grey,othresh*1.000,1.000);
	outline_section(id_grey,othresh*0.975,0.975);
	outline_section(id_grey,othresh*1.025,1.025);


	setup_results();
	setResult("Total_lo" ,ncol*ncol+2, floor(othresh*0.95));
	setResult("Total_mid",ncol*ncol+2, floor(othresh));
	setResult("Total_hi" ,ncol*ncol+2, floor(othresh*1.05));
	
	setResult("Grey_fill_lo" , ncol*ncol+2, floor(gthresh*0.975));
	setResult("Grey_fill_mid", ncol*ncol+2, floor(gthresh*1.000));
	setResult("Grey_fill_hi" , ncol*ncol+2, floor(gthresh*1.025));
	setResult("Brown_fill_lo" ,ncol*ncol+2, floor(bthresh*0.975));
	setResult("Brown_fill_mid",ncol*ncol+2, floor(bthresh*1.000));
	setResult("Brown_fill_hi" ,ncol*ncol+2, floor(bthresh*1.025));


	selectImage(id_red); setSlice(1);
	thresh_labels=newArray("Total_mid","Total_lo","Total_hi");
	thresh_colors=newArray("blue","green","red");
	for(k=2;k>-1;k--){

		roiManager("select", k);
		Roi.getCoordinates(out_x, out_y);
		makeSelection("freehand",out_x,out_y);
		getStatistics(area, mean, min, max, std, histogram);
		setResult(thresh_labels[k],ncol*ncol+1  ,area*nred*nred);

		
		makeSelection("freehand",out_x,out_y);
		Overlay.addSelection(thresh_colors[k]);
	}
	Overlay.show();


	stats = perform_area_calc(id_grey, out_x, out_y, gthresh); 
	setResult("Grey_fill_lo", ncol*ncol+1,stats[0]*nred*nred);
	setResult("Grey_fill_mid",ncol*ncol+1,stats[1]*nred*nred);
	setResult("Grey_fill_hi", ncol*ncol+1,stats[2]*nred*nred);

	cids=split_color(id_cor);
	selectImage(cids[0]);close();
	selectImage(cids[2]);close();
	stats = perform_area_calc(cids[1], out_x, out_y, bthresh); 
	setResult("Brown_fill_lo", ncol*ncol+1,stats[0]*nred*nred);
	setResult("Brown_fill_mid",ncol*ncol+1,stats[1]*nred*nred);
	setResult("Brown_fill_hi", ncol*ncol+1,stats[2]*nred*nred);

	

	selectImage(cids[1]); 
	run("Select All"); run("Copy"); close();
	selectImage(id_red); setSlice(4); run("Paste");
	
	selectImage(id_red);
	setSlice(3);

	setBatchMode(true);
	// this is an empty canvas to test the area without opening the file
	newImage("template", "", dx_i, dy_i, 1);
	id_temp=getImageID();
	
	for( i=0; i<ncol; i++){
	for( j=0; j<ncol; j++){
		nr=ncol*i+j;

		for(k=2;k>-1;k--){
			roiManager("select", k);
			Roi.getCoordinates(out_x, out_y);
			sub_x = transform_coords_red_sub( out_x, i, "x");
			sub_y = transform_coords_red_sub( out_y, j, "y");
			selectImage(id_temp);
			makeSelection("freehand",sub_x,sub_y);
			getStatistics(area, mean, min, max, std, histogram);
			setResult(thresh_labels[k],nr  ,area);
		}
	
	
		if(area>0){		
		
		id_sub=open_subimage( filepath,i,j);
		


		run("Select All");
		run("Duplicate...","grey"); 
		id_grey=getImageID();
		run("8-bit");

		/*
		updateResults();
		makeSelection("freehand",sub_x,sub_y);
		getStatistics(area, mean, min, max, std, histogram);
		setResult("Total",nr,area);
		*/
	

		selectImage(id_grey);
		stats = perform_area_calc(id_grey, sub_x, sub_y, gthresh); 
		setResult("Grey_fill_lo", nr,stats[0]);
		setResult("Grey_fill_mid",nr,stats[1]);
		setResult("Grey_fill_hi", nr,stats[2]);	
		
		selectImage(id_grey);close();
		updateResults();

		selectImage(id_sub);
		set_white_balance(id_sub, rgb_factors );
		cids=split_color(id_sub);
		selectImage(cids[0]);close();
		selectImage(cids[2]);close();
		stats = perform_area_calc(cids[1], sub_x, sub_y, bthresh); 
		updateResults();

		setResult("Brown_fill_lo", nr,stats[0]);
		setResult("Brown_fill_mid",nr,stats[1]);
		setResult("Brown_fill_hi", nr,stats[2]);


		selectImage(cids[1]);close();
		
		selectImage(id_sub);close();

		}
	}}
	selectImage(id_temp); close();
	setBatchMode(false);

	labels=newArray("Total_mid","Total_lo","Total_hi",
	                "Grey_fill_lo","Grey_fill_mid","Grey_fill_hi",
	                "Brown_fill_lo","Brown_fill_mid","Brown_fill_hi");
	for(k=0;k<labels.length;k++){
		sum=0;
		for(l=0;l<ncol*ncol;l++){
			sum=sum+getResult(labels[k],l);
		}
		setResult(labels[k],ncol*ncol,sum);
	}
	
	selectImage(id_red);
	rname = name+"_red_"+nred+"_"+ncol;
	save(path+slash+rname+".tif");
	saveAs("Results",path+slash+rname+".area.txt");
	return;
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function perform_area_calc( id_c, xsel,ysel, thresh){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	stats = newArray(3);
	// create greyscale copy
	for( i=-1; i<2; i++ ){
		th = thresh*(1+0.05*i);
		id_t = threshold_image( id_c, 10, th);
		makeSelection("freehand",xsel,ysel);
		getStatistics(area, mean, min, max, std, histogram);
		stats[i+1]=histogram[255];
		selectImage(id_t);if(isOpen(id_t)){close();}
	}
	return stats;	
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function threshold_image( idi, thresh_lo, thresh_hi){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	selectImage(idi);
	run("Select All");
	run("Duplicate...","tmp_thresh");
	id_t = getImageID();
	setThreshold(thresh_lo, thresh_hi);
	setOption("BlackBackground");
	run("Convert to Mask");
	return id_t;
}
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function count_pixels( ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	
	//getStatistics(area, mean, min, max, std, histogram);
	//frac=mean/255.;
	//return(frac*area);
	getHistogram(values, counts, 256);
	return counts[255];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function perturb_thresh( x, percent ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// x on [0:1]
	// does an tan transfomration to map to 
	y = tan(PI*(x-0.5))/PI+percent*0.5;
	return (atan(PI*y)/PI+0.5);
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function setup_file(make_reduced){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	filepath=File.openDialog("Select a File");	// Name of file 
	//filepath="/Users/evenhuis/Dropbox/UTS/sectioning/W90.10B6.007.F1.187 (1) X20.tif"
	path    =File.getParent(filepath);	     	// directory it is in
	file    =substring(filepath,lengthOf(path)+1);
	name    =trim_ext( file);

	setup_coordinates(filepath);

	// does the reduced image exist?
	redname=name+"_red_"+nred+"_"+ncol+".tif";
	redfilepath=path+slash+redname;
	id_red="";
	if( make_reduced){
		if( File.exists(redfilepath)){
		open(redfilepath);
		id_red = getImageID();
		}else{	
			id_red = create_reduced_image(filepath);
			save(redfilepath);
		}
	}
	cout=newArray(id_red,filepath,path,name);
	return cout;
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function transform_coords_red_sub( red,  i, dim  ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if( dim=="x"){ dd=dxr_i; }
	if( dim=="y"){ dd=dyr_i; }
	np=red.length;
	sub=newArray(np);
	for( k=0; k<np; k++){
		sub[k] = (red[k]-i*dd)*nred;
	}
	return sub;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function setup_results(  ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// setup results
run("Clear Results");
for(i=0;i<ncol;i++){
for(j=0;j<ncol;j++){	
	nr=ncol*i+j;
	code=alphabet[i]+toString(j);
	setResult("id",nr,code);
}}
setResult("id",ncol*ncol,"Summed");
setResult("id",ncol*ncol+1,"Downsized");
setResult("id",ncol*ncol+2,"Thresh");

return;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function open_subimage(filepath,i,j){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	batch_on =is("Batch Mode");
	if( ! batch_on){ setBatchMode(true); }

	
	x_i=i*dx_i;
	y_i=j*dy_i;	
	
	bio_options="color_mode=Composite concatenate_series crop  view=Hyperstack stack_order=XYCZT ";
	bio_coords ="x_coordinate_1="+x_i+" y_coordinate_1="+y_i+" width_1="+dx_i+" height_1="+dy_i;
	run("Bio-Formats Importer", "open=["+filepath+"]" + bio_options + bio_coords );	
	
	// Convert to RGB
	id_s = getImageID();
	run("RGB Color");
	id_rgb= getImageID();
	selectImage(id_s);  close(); 
	selectImage(id_rgb);
	
	
	rename("sub_image_"+alphabet[i]+j+".tiff");

	if( ! batch_on){
		setBatchMode(false);
	}
	return id_rgb;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function create_reduced_image(filepath){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	newImage("reduced", "RGB white", dxr, dyr, 4);
	id_map = getImageID();

	for(i=0;i<ncol;i++){
	setBatchMode(true);
	for(j=0;j<ncol;j++){
		setBatchMode(true);
		
		id_rgb = open_subimage( filepath,i,j);

		// Resize
		//selectImage(id_rgb);run("Duplicate...","resize");
		//run("Size...", "width="+dxr_i+" height="+dyr_i+" average interpolation=Bilinear"); 
		//selectImage(id_rgb);run("Duplicate...","bin");

		run("Bin...", "x="+nred+" y="+nred+" bin=Median");
	
		run("Select All");
		run("Copy");
		close();

		selectImage(id_map);
		makeRectangle( i*dxr_i, j*dyr_i, dxr_i, dyr_i);
		run("Paste");
	
	}setBatchMode(false);
	}

	// draw overlay
	for(i=0;i<ncol;i++){
	for(j=0;j<ncol;j++){	
		setColor("red");
		setLineWidth(3);
		Overlay.drawRect(i*dxr_i, j*dyr_i, dxr_i, dyr_i);
		setFont("Helvetica", floor(dxr_i/10.));
		code=alphabet[i]+toString(j);
		x0=(i+0.2)*dxr_i; y0 = (j+0.2)*dyr_i;
		Overlay.drawString(code,x0,y0);
	}}
	Overlay.show();
	return id_map;
}


// - - - - - - - - - - - - - - - - - - - - - - -
function get_meta_data( filepath ){
// - - - - - - - - - - - - - - - - - - - - - - -	
// Open the nd2 metadata and return the meta data string

path    =File.getParent(filepath);	     	// directory it is in
file    =substring(filepath,lengthOf(path)+1);

bio_options=" autoscale color_mode=Composite concatenate_series open_all_series view=Hyperstack stack_order=XYCZT";

// open the meta data
run("Bio-Formats Importer", "open=["+filepath+"] display_metadata view=[Metadata only]");
meta_win="Original Metadata - "+file;
selectWindow(meta_win);
meta_str=getInfo("window.contents");
run("Close");

return meta_str;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function extract_key_val( key, string ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	nl=lengthOf(string);
	nk=lengthOf(key);
	ns=indexOf( string, key);
	if( ns== -1 ){
		return "NA";
	}
	
	subs=substring(string,ns+nk);
	ne=indexOf(subs,"\n");
	val=substring(subs,0,ne);

	return val;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function trim_ext( string ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	nd=lastIndexOf(string,".");

	subs="";
	if(nd >=0 ){
		subs=substring(string,0,nd);
	}
	return subs; 
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function outline_section( id, thresh, f ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	selectImage(id);
	getDimensions(width, height, channels, slices, frames);
	area=width*height*0.1;
	
	run("Select None");
	run("Duplicate...","tmp"); id_t = getImageID();
	setThreshold(10,thresh);
	setOption("BlackBackground",false);
	run("Convert to Mask");

	dx=4;
	run("Gaussian Blur...", "sigma="+dx*f);

	setThreshold(0,5);
	setOption("BlackBackground",false);	
	run("Convert to Mask");
	run("Invert");

	nrod=5;
	for(i=0;i<nrod;i++){
		run("Erode");
	}

	
	run("Analyze Particles...", "size="+area+"-Infinity add");
	selectImage(id_t);	close();
	selectImage(id);

}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function split_color( id ){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// this section uses color deconv to split the channels for the stains
	selectImage(id);
	file=getTitle();
	print(file);

	//run("Colour Deconvolution", "vectors=[Methyl Green DAB] hide");
	run("Colour Deconvolution", "hide vectors=[User values] 	[r1]=0.7184294 [g1]=0.33015305 [b1]=0.61225665 [r2]=0.2035166 [g2]=0.509158 [b2]=0.83626497 [r3]=0.4028809 [g3]=0.8235709 [b3]=0.39927173");
	selectWindow(file+"-(Colour_1)"); c1= getImageID();
	selectWindow(file+"-(Colour_2)"); c2= getImageID();
	selectWindow(file+"-(Colour_3)"); c3= getImageID();
	ids=newArray(c1,c2,c3);
	return ids;
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function setup_coordinates(filepath){
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

//1.   Downsize the image
//  a. Get the pxiel dimensions of the image
meta_data = get_meta_data(filepath);
sizeX0 = parseInt(extract_key_val("SizeX",meta_data));
sizeY0 = parseInt(extract_key_val("SizeY",meta_data));

// round to nearest multiple of division factor
sizeX0 = floor(sizeX0/(nred*ncol))*nred*ncol;
sizeY0 = floor(sizeY0/(nred*ncol))*nred*ncol;



// These are the sizes of the boxes in the subsample
dx_i = floor(sizeX0/ncol);		// sub boxes on the full image
dy_i = floor(sizeY0/ncol);		

dxr_i = floor(sizeX0/(nred*ncol)); // sub boxes on the reduced image
dyr_i = floor(sizeY0/(nred*ncol));

dxr=ncol*dxr_i;	// size of reduced image
dyr=ncol*dyr_i;   
return;
}

