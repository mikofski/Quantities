classdef unitRegistry < containers.Map
    properties (SetAccess=private)
        xmlfile % path to xml file
        prefixes = {} % cell string of prefix keys
        dimensions = {} % cell string of dimension keys
        units = {} % cell string of unit keys
        constants = {} % cell string of constant keys
        verbosity = 0 % set verbosity 0:none, 1:info, 2:debug, 3:warning
        status = 0 % status of upload
    end
    properties (Constant)
        LOG_LEVELS = {'info','debug','warning'}
    end
    methods
        function ureg = unitRegistry(varargin)
            % call superclass constructor
            ureg = ureg@containers.Map({Quantities.unit.DIMENSIONLESS.name,'pi'},...
                {Quantities.unit.DIMENSIONLESS,Quantities.constant.PI});
            % parse inputs
            p = inputParser;
            function validate_xmlfile(f)
                assert(exist(f,'file')==2,'unitRegistry:xmlfile','bad path')                
            end
            p.addOptional('xmlfile',...
                fullfile(fileparts(mfilename('fullpath')),'default_en.xml'),...
                @validate_xmlfile)
            p.addOptional('verbosity',0,@(arg)validateattributes(arg,{'numeric'},...
                {'scalar','integer','nonnegative'},'unitRegistry','verbosity',2))
            p.parse(varargin{:});
            args = p.Results;
            ureg.xmlfile = args.xmlfile;
            ureg.verbosity = args.verbosity;
            % get xml document object model
            xdoc = xmlread(ureg.xmlfile);
            xroot = xdoc.getDocumentElement;
            % number of values in xmlfile
            xprefixes = xroot.getElementsByTagName('prefix');
            nxml_prefixes = xprefixes.getLength;
            xdims = xroot.getElementsByTagName('dimension');
            nxml_dims = xdims.getLength;
            xconsts = xroot.getElementsByTagName('constant');
            nxml_consts = xconsts.getLength;
            xunits = xroot.getElementsByTagName('unit');
            nxml_units = xunits.getLength;
            nxml = nxml_prefixes+nxml_dims+nxml_consts+nxml_units;
            % initialize counts
            lastcount = -1;
            nreg_prefixes = 0;
            nreg_dims = 0;
            nreg_consts = 0;
            nreg_units = 0;
            nreg = 0;
            % loop until all xml contents loaded or error thrown
            while nreg<nxml
                % throw exception if no new xml contents were loaded
                assert(lastcount~=nreg,'unitRegistry:xmlfile',...
                    'The xml file either has a missing dependency or is circular.')
                % prefixes
                attrs = struct('name',{'name','value'},'default',{'',1},...
                    'hook',{@char,@ureg.get_value});
                jdx = nreg_prefixes;
                for idx = 0:nxml_prefixes-1
                    xprefix = xprefixes.item(idx);
                    % skip if already loaded
                    if any(strcmp(char(xprefix.getAttribute('name')),ureg.prefixes))
                        continue
                    end
                    retv = Quantities.unitRegistry.reg_parser(xprefix,attrs);
                    % skip if missing dependency
                    if ureg.status<0
                        continue
                    end
                    jdx = jdx+1;
                    aliases = Quantities.unitRegistry.get_tag_text_list(xprefix,'alias');
                    pre = Quantities.prefix(retv{:},aliases);
                    subsasgn(ureg,substruct('()',{pre.name}),pre);
                    ureg.prefixes{jdx} = pre.name;
                    ureg.logging('debug','loading prefix: %s',pre.name)
                end
                % dimensions
                % uses same attributes from prefixes
                jdx = nreg_dims;
                for idx = 0:nxml_dims-1
                    xdim = xdims.item(idx);
                    % skip if already loaded
                    if any(strcmp(char(xdim.getAttribute('name')),ureg.dimensions))
                        continue
                    end
                    retv = Quantities.unitRegistry.reg_parser(xdim,attrs);
                    % skip if missing dependency
                    if ureg.status<0
                        continue
                    end
                    jdx = jdx+1;
                    dim = Quantities.dimension(retv{:});
                    subsasgn(ureg,substruct('()',{dim.name}),dim);
                    ureg.dimensions{jdx} = dim.name;
                    ureg.logging('debug','loading dimension: %s',dim.name)
                end
                % constants
                % uses same attributes from prefixes
                jdx = nreg_consts;
                for idx = 0:nxml_consts-1
                    xconst = xconsts.item(idx);
                    % skip if already loaded
                    if any(strcmp(char(xconst.getAttribute('name')),ureg.constants))
                        continue
                    end
                    retv = Quantities.unitRegistry.reg_parser(xconst,attrs);
                    % skip if missing dependency
                    if ureg.status<0
                        continue
                    end
                    jdx = jdx+1;
                    aliases = Quantities.unitRegistry.get_tag_text_list(xconst,'alias');
                    const = Quantities.constant(retv{:},aliases);
                    subsasgn(ureg,substruct('()',{const.name}),const);
                    ureg.constants{jdx} = const.name;
                    ureg.logging('debug','loading constant: %s',const.name)
                end
                % units
                attrs = struct('name',{'name','dimensionality','value'},...
                    'default',{'',[],1},...
                    'hook',{@char,@ureg.get_value,@ureg.get_value});
                jdx = nreg_units;
                for idx = 0:nxml_units-1
                    xunit = xunits.item(idx);
                    % skip if already loaded
                    if any(strcmp(char(xunit.getAttribute('name')),ureg.units))
                        continue
                    end
                    retv = Quantities.unitRegistry.reg_parser(xunit,attrs);
                    % skip if missing dependency
                    if ureg.status<0
                        continue
                    end
                    jdx = jdx+1;
                    aliases = Quantities.unitRegistry.get_tag_text_list(xunit,'alias');
                    unit = Quantities.unit(retv{:},aliases);
                    subsasgn(ureg,substruct('()',{unit.name}),unit);
                    ureg.units{jdx} = unit.name; % add name to units cellstring
                    ureg.logging('debug','loading unit: %s',unit.name)
                end
                % number of values in registry
                lastcount = nreg;
                nreg_prefixes = numel(ureg.prefixes);
                nreg_dims = numel(ureg.dimensions);
                nreg_consts = numel(ureg.constants);
                nreg_units = numel(ureg.units);
                nreg = nreg_prefixes+nreg_dims+nreg_consts+nreg_units;
            end
        end
        function F = subsref(ureg,s)
            switch s(1).type
                case '()'
                    % if key not found, search for aliases and prefixes
                    try
                        F = subsref@containers.Map(ureg,s); % base class subsref
                    catch ME
                        % only catch MATLAB:Containers:Map:NoKey exception
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                        % search aliases
                        % loop through units and compare s.subs to aliases
                        % TODO: search constants for aliases too
                        s_unit = substruct('.','units');
                        for u = subsref@containers.Map(ureg,s_unit);
                            aliases = subsref@containers.Map(ureg,...
                                substruct('()',u,'.','aliases'));
                            if any(strcmp(s(1).subs,aliases))
                                s(1).subs = u;
                                F = subsref@containers.Map(ureg,s);
                                return
                            end
                        end
                        % search prefixes
                        s_prefix = substruct('.','prefixes');
                        for p = subsref@containers.Map(ureg,s_prefix);
                            u = [];
                            % check prefix and its aliases
                            prefix = subsref@containers.Map(ureg,...
                                substruct('()',p));
                            len_prefix = numel(prefix.name);
                            % get alias indices checking 1st letter
                            alias_idx = strncmp(s(1).subs,prefix.aliases,1);
                            if any(strncmp(s(1).subs,prefix.name,len_prefix));
                                % get unit name
                                u = s(1).subs{1}(len_prefix+1:end);
                            elseif any(alias_idx);
                                % get alias
                                prefix_alias = prefix.aliases(alias_idx);
                                assert(sum(alias_idx)==1,...
                                    'unitRegistry:subsref',...
                                    'Prefix aliases can''t have same first letter.')
                                prefix_alias = prefix_alias{1};
                                % get unit name
                                u = s(1).subs{1}(numel(prefix_alias)+1:end);
                            end
                            % return if matching unit found without prefix
                            % get unit
                            % TODO: refactor to eliminate redundancy
                            if ~isempty(u)
                                try
                                    u = subsref@containers.Map(ureg,substruct('()',{u}));
                                catch ME
                                    % only catch MATLAB:Containers:Map:NoKey exception
                                    if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                                        rethrow(ME)
                                    end
                                    % search aliases
                                    % loop through units and compare s.subs to aliases
                                    for reg_unit = subsref@containers.Map(ureg,s_unit);
                                        aliases = subsref@containers.Map(ureg,...
                                            substruct('()',reg_unit,'.','aliases'));
                                        if any(strcmp(u,aliases))
                                            u = subsref@containers.Map(ureg,...
                                                substruct('()',reg_unit));
                                            break
                                        end
                                    end
                                end
                                if isa(u,'Quantities.unit')
                                    F = prefix.*u;
                                    if numel(s)>1
                                        F = subsref(F,s(2:end));
                                    end
                                    return
                                end
                            end
                        end
                        throw(ME)
                    end
                case '.'
                    % allow dot notation indexing for registry contents
                    try
                        stry = s;stry(1).type = '()';stry(1).subs = {s(1).subs};
                        F = subsref(ureg,stry);
                    catch ME
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                        F = subsref@containers.Map(ureg,s);
                    end
                otherwise
                    F = subsref@containers.Map(ureg,s);
            end
        end
        function value = get_value(ureg,value)
            [v,d] = Quantities.unit.parse_name(char(value));
            value = 1;
            for idx = 1:numel(v)
                val = str2double(v{idx});
                if isnan(val)
                    val = strtrim(v{idx});
                    try
                        val = subsref(ureg,substruct('()',{val}));
                    catch ME
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                            ureg.status = -1; % key could not be found
                            return
                    end
                end
                ureg.status = 0; % success
                value = value.*val.^d(idx);
            end
        end
        function logging(ureg,level,msg,varargin)
            nlevels = 1:numel(Quantities.unitRegistry.LOG_LEVELS);
            level = validatestring(level,Quantities.unitRegistry.LOG_LEVELS,...
                'logging','level',2);
            level = nlevels(strcmp(level,{'info','debug','warning'}));
            if ureg.verbosity>=level
                fprintf([msg,'\n'],varargin{:});
            end
        end
    end
    methods (Static)
        function retv = reg_parser(xnode,attrs)
            % REG_PARSER Parser for registry files
            %
            % :param xnode: node in xml file
            % :param attrs: structure of attributes and defaults
            % :param taglist: name of tag used to list text
            
            num_attr = numel(attrs);
            retv = cell(1,num_attr);
            for idx = 1:num_attr
                retv{idx} = xnode.getAttribute(attrs(idx).name);
                if retv{idx}.isEmpty
                    retv{idx} = attrs(idx).default;
                else
                    retv{idx} = attrs(idx).hook(retv{idx});
                end
            end
        end
        function list = get_tag_text_list(xnode,tag)
            % GET_TAG_TEXT_LIST Get list of text content from tags.
            xlist = xnode.getElementsByTagName(tag);
            nlist = xlist.getLength;
            list = cell(1,nlist);
            for idx = 0:nlist-1
                list{idx+1} = char(xlist.item(idx).getTextContent);
            end
        end
    end
end
