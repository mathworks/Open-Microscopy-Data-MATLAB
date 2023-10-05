%% Access data from Open Microscopy database
% Authors: Shubo Chakrabarti and Thomas Künzel
% Copyright 2023 The MathWorks® Inc

% Introduction
% *Public Data:* Many public databases have been created for the purposes of 
% making data freely accessible to the scientific community. A best practice is 
% to assign a unique identifier to a dataset, so that it is discoverable. A common 
% form of a unique identifier is a <https://en.wikipedia.org/wiki/Digital_object_identifier 
% Digital Object Identifier or DOI®> which points to the data. 
% 
% *Access Public Data:* To access and process public data, you can use several 
% routes. 

% * Download data files to your local machine and work with them in MATLAB®. 
% * Access data directly via an API. MATLAB's <https://www.mathworks.com/help/matlab/ref/webread.html?searchHighlight=webread&s_tid=srchtitle_webread_1 
% |webread|> function reads the RESTful API used by many portals.
% * If the portal offers only Python® bindings, <https://www.mathworks.com/help/matlab/call-python-libraries.html 
% call Python from MATLAB>.

% *Data formats:* MATLAB supports a wide range of data formats

% * There are a wide range of scientific data formats that can be <https://www.mathworks.com/help/matlab/scientific-data.html 
% natively read in MATLAB>. They include NetCDF and HDF5 as well as more specialized 
% data formats. 
% * In addition, the <https://www.mathworks.com/products/bioinfo.html Bioinformatics 
% Toolbox™> contains <https://www.mathworks.com/help/bioinfo/ug/data-formats-and-databases.html 
% built-in functions> to read data from many online data repositories in standard 
% bioinformatics data formats.
% * Sometimes data import functions may be <https://www.mathworks.com/matlabcentral/fileexchange?q=data+read 
% written by the community>, and published on the MATLAB <https://www.mathworks.com/matlabcentral/fileexchange/ 
% File Exchange> - a portal for community contributions in MATLAB. All community 
% contributions are covered by open source licenses, which means they can be re-used, 
% modified or added to. Exact terms and conditions depend on the licenses used 
% by the authors.

% In this example, we will access microscopy data from the Image Data Resource 
% (IDR) on the <https://idr.openmicroscopy.org/ Open Microscopy database>. 

%% Access the data from Open Microscopy
% Access a list of all publicly available projects
% Clear the workspace
clearvars; clc

% Construct some url addresses to query the data
baseUrl = "https://idr.openmicroscopy.org"; % main portal
projectsUrl = baseUrl + "/webgateway/proj/list/"; % list of projects

% Read in all the projects available on the database into a <https://www.mathworks.com/help/matlab/ref/table.html 
% table> 
projects = webread(projectsUrl);
projectTable = struct2table(projects);

% Some rows have _/experiment_ as a suffix to their names. These are projects 
% containing actual data. Only display these and sort them by their IDs
projectTable = projectTable(contains(projectTable.name,"/experiment"),:);
projectTable = sortrows(projectTable,"id");

% Convert the text into the datatype string for easier indexing and manipulation
projectTable.name = string(projectTable.name);
projectTable.description = string(projectTable.description);

% write project table to Excel® file
writetable(projectTable,"projectTable.xlsx");

%% Access metadata on one single project
% First, extract the descriptions of each project 
descriptions = strings(height(projectTable),1);
for ii = 1:length(descriptions)
    prjMetadata = splitlines(projectTable.description(ii));
    descriptions(ii) = string(prjMetadata(2));
end

% Let the user choose from a list of projects
thisProject = descriptions(87);
projectMatches = projectTable(descriptions==thisProject,:);


% If multiple experiments correspond to one project, let the user choose the 
% experiment
if height(projectMatches) > 1
    ExptNames = projectMatches.name;
    ExptNames = split(ExptNames,"/");
    ExptNames = ExptNames(:,2);
    selectedExpt = ExptNames(1);
    projectMatches = projectMatches(contains(projectMatches.name,selectedExpt),:);
end

thisProject = projectMatches.id;

% Query this particular project and list all the metadata associated with that 
% project
projectInfoUrl = baseUrl + "/webgateway/proj/"+num2str(thisProject)+"/detail/";
projectInfo = webread(projectInfoUrl);
projectInfo.description = splitlines(projectInfo.description);
projectInfo.PublicationTitle = string(projectInfo.description(2));
projectInfo.description = string(projectInfo.description(5));

% Often, projects (and datasets and images) can be accompanied by further *annotations*. 
% Let's read the annotations attached to this project:
allAnnotations = webread(baseUrl + "/webclient/api/annotations/?project=" + num2str(projectInfo.id));

% Take the first annotation ("MapAnnotationI") containing the metadata related 
% to the project including the publication DOI and turn it into a dictionary using 
% the MATLAB function |dictionary|
annotationValues = horzcat(allAnnotations.annotations{1}.values{:});
annotationValues = cellfun(@string, annotationValues);
annotationDictionary = dictionary(annotationValues(1,:),annotationValues(2,:));

% Next, we read in all the datasets related to this project
projectDatasetUrl = baseUrl + "/webgateway/proj/"+num2str(thisProject)+"/children/";
datasets = webread(projectDatasetUrl);

%% Access single dataset from project
% Access data from a single dataset selected from the above table

thisDatasetNames = string({datasets.name}');
datasetName = thisDatasetNames(8);
datasetID = datasets(thisDatasetNames==datasetName).id;

%% Access individual microscopy images from dataset
% Accessing this dataset yields its metadata...
datasetInfo = webread(baseUrl + "/webgateway/dataset/"+string(datasetID)+"/detail/");
 
% ...and all images associated with this dataset
datasetImages = webread(baseUrl + "/webgateway/dataset/"+string(datasetID)+"/children/");
datasetImages = struct2table(datasetImages,"AsArray",true);

% There are two ways to access these images. 

% # Accessing the thumbnails - these are smaller in size and available by querying 
% the url specified in the related |thumb_url| variable of the |datasetImages| 
% table
% # Accessing the full image by its ID

% First, load all the image thumbnails for a visual inspection
datasetImages.thumb_url = string(datasetImages.thumb_url);
nImagesInDataset = height(datasetImages);
thumb = cell(1, nImagesInDataset); % preallocate memory for cell array
for thisImage = 1:nImagesInDataset
    thumb{thisImage} = webread(baseUrl + datasetImages.thumb_url(thisImage)); 
end
figure
montage(thumb,"BorderSize",10,"BackgroundColor","white","ThumbnailSize",[128 128]);
saveas(gcf,"MontageFigure.png")

%% Next, load a single full image from the selected dataset to look at it more 
% closely. For this, you need the image number from the above montage
thisImage = 4;
thisImageUrl = baseUrl + "/webgateway/render_image/"+string(datasetImages.id(thisImage));
fullImage = webread(thisImageUrl); 
figure
imshow(fullImage)
saveas(gcf,"FullImageFigure.png")

%% Simple Cell Counting (in the Image chosen above)
% Use a very simple thresholding method to count cells in images.
% 
% First, convert the image to a grayscale image using the function |im2gray|
grayImage = im2gray(fullImage);
figure
imshow(grayImage)
saveas(gcf,"GrayImageFigure.png")

% Next, convert the grayscale image to a binary image using a user-specified 
% threshold
thr = 90;
bwImage = grayImage > thr;
figure
imshow(bwImage)
saveas(gcf,"BWImageFigure.png")

% Now start counting the cells. Use the command |regionprops| to define the 
% cells (white areas) and |bwboundaries| to draw boundaries around each cell
cells = regionprops(bwImage,"all");
boundaries = bwboundaries(bwImage,"noholes");

% A user-defined minimal pixel count specifies criteria for defining cells and 
% boundaries based on their total volume to reject small debris from being counted
minPixelCount = 200;
boundaries = boundaries([cells.Area] > minPixelCount);
cells = cells([cells.Area] > minPixelCount);
centroids = vertcat(cells.Centroid);

% Plot the boundaries and centroids on top of the original image. The boundaries 
% can be smoothed using the |smoothingFactor| user control object
figure
imshow(fullImage);
smoothingFactor = 31; 
hold on
for iBound = 1:numel(boundaries)
    thisBound = boundaries{iBound};
    plot(smooth(thisBound(:,2),smoothingFactor), smooth(thisBound(:,1),smoothingFactor), 'w', 'LineWidth', 0.5);
end
plot(centroids(:,1), centroids(:,2),"rx", "MarkerSize",12)
title("Image-ID: " + num2str(datasetImages.id(3)) + " / " + datasetImages.name(3), "Interpreter","none");
saveas(gcf,"ImageWithCentroidsFigure.png")

%% Publish reusable MATLAB code for reproducible results
% 
% To enable collaboration partners, reviewers and the community reuse your MATLAB 
% code and reproduce your results.

% * Publish your MATLAB code (eg: on GitHub) and generate a <https://en.wikipedia.org/wiki/Digital_object_identifier 
% DOI> (digital object identifier) by <https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content 
% linking it to a DOI generating portal>(egs. <https://help.figshare.com/article/how-to-connect-figshare-with-your-github-account#:~:text=You%20can%20get%20set%20up,where%20you'll%20authorise%20figshare. 
% Figshare>, <https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content>). Make your research output findable by including as much 
% information as needed in the metadata. Document your code well explaining steps 
% required to reproduce clearly and explicitly.

% * Make sure you include a license for your code that specifies reuse and re-distribution rights for the code. Various open source licenses 
% are available. <https://opensource.org/licenses/>
% BSD, MIT and Apache licenses are commonly used for open research software.

% * <https://www.mathworks.com/matlabcentral/content/fx/about.html?s_tid=gn_mlc_fx_help#Why_GitHub 
% Link your GitHub repository to File Exchange> to make your MATLAB code available 
% to MATLAB users via the Add-Ons button.  
% 

% * Make your MATLAB code *interoperable*. MATLAB is <https://www.mathworks.com/products/matlab/matlab-and-other-programming-languages.html 
% interoperable> with several other languages including C, Fortran and Python. 
% MATLAB can be directly called from Python using the <https://www.mathworks.com/help/matlab/matlab-engine-for-python.html 
% MATLAB Engine for Python> which is available as a PyPI package and can be installed 
% using the command |pip install matlab.engine| from Python. MATLAB code can also 
% be <https://www.mathworks.com/help/compiler_sdk/gs/create-a-python-application-with-matlab-code.html 
% packaged as a Python library> and called from Python. Deep Learning models from 
% other frameworks are <https://www.mathworks.com/help/deeplearning/ug/interoperability-between-deep-learning-toolbox-tensorflow-pytorch-and-onnx.html 
% interoperable with MATLAB> either using the <https://www.mathworks.com/matlabcentral/fileexchange/67296-deep-learning-toolbox-converter-for-onnx-model-format 
% ONNX interface> or via direct interfaces that exist, for example, for Pytorch 
% and Tensorflow models. 

% * MATLAB is interoperable with cloud architectures such as <https://www.mathworks.com/products/reference-architectures/jupyter.html 
% JupyterHub> and MATLAB code can also be used within Jupyter Notebooks. Here 
% is a link to a Jupyter notebook of the same example used here. There is an official 
% MATLAB kernel for Jupyter Notebooks - read about it <https://blogs.mathworks.com/matlab/2023/01/30/official-mathworks-matlab-kernel-for-jupyter-released/ 
% here>.To easily convert a Live Script into a Jupyter Notebook use the export function.

% * Run your <https://www.mathworks.com/help/matlab/matlab_env/open-github-repositories-in-matlab-online.html 
% MATLAB code on the browser directly from GitHub>. Copy and paste the GitHub 
% repo address into <https://www.mathworks.com/products/matlab-online/git.html 
% this app>. That will generate a command, which when pasted into your README, 
% will create a "Open in MATLAB Online" button on your GitHub repository. By clicking 
% on this button, users will be able to run your code in the browser on MATLAB 
% Online.
 
% * Make your MATLAB code reproducible by using a reproducibility portals that 
% supports MATLAB. One example is Code Ocean. On Code Ocean, you can <https://help.codeocean.com/en/articles/1120384-which-toolboxes-are-included-with-matlab 
% upload your MATLAB code> including dependencies. Once uploaded, your code is 
% tested and published as a Code Ocean "capsule" which can be run online or downloaded 
% and run locally by users. Code Ocean also generates a DOI for your code capsule. 
% For Live Scripts, convert the |.mlx| file into a |.m| file and a |.html| file 
% for best results. Here is the DOI <https://doi.org/10.24433/CO.8820386.v2> for the Code Ocean capsule of the this code. 
% Read more about MATLAB on Code Ocean <https://blogs.mathworks.com/loren/2021/07/15/sharing-and-running-matlab-code-in-the-cloud/#H_795BB86B 
% here>.
 
% * *Warning*: Before making your code available on the cloud, make sure all 
% dependencies including any data that is needed for your code to run is uploaded 
% along with the code. Also make sure any path and/or filenames that refer to 
% local directories are appropriately renamed.
% * FAIR standards: FAIR is an acronym that stands for *F*indable, *A*ccessible, 
% *I*nteroperable and *R*eproducible. It is an <https://www.nature.com/articles/s41597-022-01710-x 
% accepted standard> for research output (code, data) and is often required for 
% your research results to be in <https://research-and-innovation.ec.europa.eu/strategy/strategy-2020-2024/our-digital-future/open-science_en 
% compliance with "Open Science" standards>. Adhering to the above pointers helps 
% in making your MATLAB code FAIR
