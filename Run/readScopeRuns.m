function [data] = readScopeRuns(url, run_rows)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [data] = readScopeRuns(url, varargin)
%
% READSCOPERUNSNEW looks up a published Google Sheet (by URL/ID) and requests 
% it as a CSV. It then pulls out data corresponding to specified ID(s)
%
% url         input Google Sheet URL
% run_rows    IDs corresponding to rows on Google Sheet (1 row per experimental condition)
%
% data        information from row(s) corresponding to input data
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if nargin<2
    error('ERROR: specify at least 1 ID number from ''Scope Runs'' spreadsheet')
end

% Find the sheet ID based on the URL. We can then do our query
% Below line contains regex "pattern" with names groups for id and gid

reMatch = regexp(url, '/docs.google.com\/spreadsheets\/d\/(?<id>[^\/]+)(?<remainder>[^#]*)', 'names');

% Check if we found a match for ID
if isempty(reMatch) || ~isfield(reMatch, 'id') || isempty(reMatch.id)
    error("ERROR: Couldn''t find the spreadsheet ID in the sheet!")
end

full_url = "https://docs.google.com/spreadsheets/d/" + reMatch.id + "/export?format=csv";

% check if there was a gid (a tab specified)
if isfield(reMatch, 'remainder') && ~isempty(reMatch.remainder)
    gidPattern = '\/[^?]+[?].*(gid=)(?<gid>.*)';
    gidMatch = regexp(reMatch.remainder, gidPattern, 'names');
    if ~isempty(gidMatch) && isfield(gidMatch, 'gid') && ~isempty(gidMatch.gid)
        full_url = full_url + "&gid=" + gidMatch.gid;        
    end
end

% Pull it in, preserving the original variable names and keeping datetimes
% as text to avoid incorrect parsing/getting a bunch of annoying error messages
opts = detectImportOptions(full_url,"VariableNamingRule", "preserve", "DatetimeType","text");
r = readtable(full_url, opts);

% REMOVE ALL SPACES AND LOWERCASE ALL LETTERS FROM VARIABLE NAMES
r.Properties.VariableNames = cellfun(@(data) lower(data(~isspace(data))), r.Properties.VariableNames, 'UniformOutput', false);

% CHECK IF THE COLUMN # EXISTS
if ~ismember('#', r.Properties.VariableNames)
    error('ERROR: Could not find a column named "#" in spreadsheet.');
end

% Find the rows we want (the ones mentioned in run_rows)
relevant_rows = r(ismember(r.("#"),run_rows),:);

missing_requested_rows = setdiff(run_rows, relevant_rows.('#'));

% If we didn't find anything we asked for
if height(relevant_rows) == 0
    error("ERROR: Could not find any rows in the sheet also listed in the target rows");
end

% If we asked for at least one thing that wasn't in the spreadsheet
if not(isempty(missing_requested_rows))
    error(strcat("ERROR: Could not find row(s) " + strjoin(string(missing_requested_rows), ", ") + " in sheet!"));
end

% Expected columns
expectedFields = {'#', 'foldername', 'imagepath', 'xy', 't', 'paramsfile', 'savepath', 'otherparams', 'dose'};

% Check for missing columns
missingFields = setdiff(expectedFields, relevant_rows.Properties.VariableNames);
if ~isempty(missingFields)
    error("ERROR: Missing expected columns: %data", strjoin(missingFields, ", "));
end

data = struct();
data.save_folder = relevant_rows.foldername;
data.image_paths = relevant_rows.imagepath;
data.xy_ranges = relevant_rows.xy;
data.time_ranges = relevant_rows.t;
data.parameter_files = relevant_rows.paramsfile;
data.save_dir = relevant_rows.savepath;
data.modify = relevant_rows.otherparams;

data.dose = relevant_rows.dose;

% Double check that all necessary data was found and take only selected
% rows
% NOTE: THE FOLLOWING IS REMAINING FROM A PRIOR VERSION
% TODO: Check if it should be removed or revised.
types = fieldnames(data);
for i = 1:length(types)
    if isempty(data.(types{i}))
        error(['ERROR: Couldn''t find column "',types{i},'" in spreadsheet.'])
    end
    % Already did the following so I'm commenting it out
    %data.(types{i}) = data.(types{i})(locs);
end
