function [varargout]=plot0(data,varargin)
%PLOT0    Evenly spaced plot of SEIZMO records
%
%    Usage:    plot0(data)
%              plot0(...,'option',value,...)
%              ax=plot0(...)
%
%    Description:
%     PLOT0(DATA) draws all non-xyz records in SEIZMO struct DATA in a new
%     figure in the same axes.  The records are normalized as a group (with
%     a maximum amplitude range of 1/3 the yaxis range) and spaced at unit
%     distance from one another.  Each record is drawn as a distinct color
%     from the HSV colormap.  Spectral records are converted to the time
%     domain prior to plotting.
%
%     PLOT0(...,'OPTION',VALUE,...) sets certain plotting options to do
%     simple manipulation of the plots.  Available options are:
%      FGCOLOR      -- foreground color (axes, text, labels)
%      BGCOLOR      -- background color (does not set figure color)
%      AXIS         -- axes to plot in
%      COLORMAP     -- colormap for coloring data
%      XLABEL       -- x axis label
%      YLABEL       -- y axis label
%      TITLE        -- title
%      XLIM         -- x axis limits (tight by default)
%      YLIM         -- y axis limits (tight by default)
%      LINEWIDTH    -- line width of records (default is 1)
%      LINESTYLE    -- line style of records (can be char/cellstr array)
%      NUMCOLS      -- number of subplot columns
%      UTC          -- plot in absolute time if TRUE (UTC, no leap support)
%      DATEFORMAT   -- date format used if ABSOLUTE (default is auto)
%      NORMSTYLE    -- normalize 'individually' or as a 'group'
%      NORMMAX      -- max value of normalized records
%      NORM2YAXIS   -- scale to yaxis range (NORMMAX is fraction of range)
%      NAMESONYAXIS -- true/false or 'kstnm' 'stcmp' 'kname'
%      XDIR         -- 'normal' or 'reverse'
%      YDIR         -- 'normal' or 'reverse'
%      FONTSIZE     -- size of fonts in the axes
%      XSCALE       -- 'linear' or 'log'
%      YSCALE       -- 'linear' or 'log'
%      AMPSCALE     -- 'linear' or 'log'
%
%     AX=PLOT0(...) returns the handle for the axis drawn in.  This is
%     useful for more detailed plot manipulation.
%
%    Notes:
%     - Confusing: Positive values go in the opposite direction that record
%       number increases.  This means positive amplitudes are "up" in the
%       default case ('ydir' is 'reverse').
%
%    Examples:
%     % add station+component names to the yaxis
%     plot0(data,'namesonyaxis','stcmp')
%
%    See also: PLOT1, PLOT2, RECORDSECTION

%     Version History:
%        Aug. 14, 2010 - rewrite
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Aug. 14, 2010 at 23:00 GMT

% todo:

% check nargin
error(nargchk(1,inf,nargin));

% check struct
error(seizmocheck(data,'dep'));
nrecs=numel(data);

% default/parse options
opt=parse_seizmo_plot_options(varargin{:});

% line coloring
if(ischar(opt.CMAP) || iscellstr(opt.CMAP))
    % list of color names or a colormap function
    try
        % attempt color name to rgb conversion first
        opt.CMAP=name2rgb(opt.CMAP);
        opt.CMAP=repmat(opt.CMAP,ceil(nrecs/size(opt.CMAP,1)),1);
    catch
        % guess its a colormap function then
        opt.CMAP=str2func(opt.CMAP);
        opt.CMAP=opt.CMAP(nrecs);
    end
else
    % numeric colormap array
    opt.CMAP=repmat(opt.CMAP,ceil(nrecs/size(opt.CMAP,1)),1);
end

% line style
opt.LINESTYLE=cellstr(opt.LINESTYLE);
opt.LINESTYLE=opt.LINESTYLE(:);
opt.LINESTYLE=repmat(opt.LINESTYLE,ceil(nrecs/size(opt.LINESTYLE,1)),1);

% check filetype (only timeseries or xy)
iftype=getenumid(data,'iftype');
time=strcmpi(iftype,'itime') | strcmpi(iftype,'ixy');
spec=strcmpi(iftype,'irlim') | strcmpi(iftype,'iamph');
goodfiles=find(time | spec)';

% convert spectral to timeseries
if(sum(spec)); data(spec)=idft(data(spec)); end

% header info
leven=getlgc(data,'leven');
[b,npts,delta,depmin,depmax,z6,kname]=getheader(data,...
    'b','npts','delta','depmin','depmax','z6','kname');
depmin=abs(depmin);
depmax=abs(depmax);
z6=datenum(cell2mat(z6));

% normalize
if(opt.NORM2YAXIS)
    scale=nrecs*opt.NORMMAX/2;
else
    scale=P.NORMMAX;
end
switch opt.NORMSTYLE
    case {'single' 'individually' 'individual' 'one' 'separately'}
        switch lower(opt.AMPSCALE)
            case 'linear'
                ampmax=max(depmin,depmax);
                ampmax(ampmax==0)=1; % avoid NaNs
                for i=goodfiles
                    data(i).dep=i-data(i).dep/ampmax(i)*scale;
                end
            case 'log'
                for i=goodfiles
                    logmin=min(log10(data(i).dep(data(i).dep>0)));
                    logmax=max(log10(data(i).dep(data(i).dep>0)));
                    logrng=logmax-logmin;
                    if(~logrng); logrng=1; end % avoid NaNs
                    data(i).dep=i-...
                        (2*((log10(data(i).dep)-logmin)/logrng)-1)*scale;
                end
        end
    case {'group' 'together' 'all'}
        switch lower(opt.AMPSCALE)
            case 'linear'
                ampmax=max([depmin; depmax]);
                ampmax(ampmax==0)=1; % avoid NaNs
                for i=goodfiles
                    data(i).dep=i-data(i).dep/ampmax*scale;
                end
            case 'log'
                logmin=nan(nrecs,1);
                logmax=nan(nrecs,1);
                for i=goodfiles
                    logmin(i)=min(log10(data(i).dep(data(i).dep>0)));
                    logmax(i)=max(log10(data(i).dep(data(i).dep>0)));
                end
                logmin=min(logmin);
                logmax=max(logmax);
                logrng=logmax-logmin;
                if(~logrng); logrng=1; end % avoid NaNs
                for i=goodfiles
                    data(i).dep=i-...
                        (2*((log10(data(i).dep)-logmin)/logrng)-1)*scale;
                end
        end
end

% all in one plot
if(isempty(opt.AXIS) || ~isscalar(opt.AXIS) || ~isreal(opt.AXIS) ...
        || ~ishandle(opt.AXIS) || ~strcmp('axes',get(opt.AXIS,'type')))
    % new figure
    figure('color',opt.BGCOLOR);
    opt.AXIS=gca;
else
    cla(opt.AXIS,'reset');
end

% adjust current axis
set(opt.AXIS,'ydir',opt.YDIR,'xdir',opt.XDIR,...
    'xscale',opt.XSCALE,'yscale',opt.YSCALE,...
    'fontsize',opt.FONTSIZE,'color',opt.BGCOLOR,...
    'xcolor',opt.FGCOLOR,'ycolor',opt.FGCOLOR);

% loop through every record
hold(opt.AXIS,'on');
for i=goodfiles
    switch leven{i}
        case 'false'
            if(opt.ABSOLUTE)
                plot(opt.AXIS,z6(i)+data(i).ind/86400,data(i).dep,...
                    'color',opt.CMAP(i,:),...
                    'linestyle',opt.LINESTYLE{i},...
                    'linewidth',opt.LINEWIDTH);
            else
                plot(opt.AXIS,data(i).ind,data(i).dep,...
                    'color',opt.CMAP(i,:),...
                    'linestyle',opt.LINESTYLE{i},...
                    'linewidth',opt.LINEWIDTH);
            end
        otherwise
            if(opt.ABSOLUTE)
                plot(opt.AXIS,...
                    z6(i)+(b(i)+(0:npts(i)-1)*delta(i)).'/86400,...
                    data(i).dep,...
                    'color',opt.CMAP(i,:),...
                    'linestyle',opt.LINESTYLE{i},...
                    'linewidth',opt.LINEWIDTH);
            else
                plot(opt.AXIS,(b(i)+(0:npts(i)-1)*delta(i)).',...
                    data(i).dep,...
                    'color',opt.CMAP(i,:),...
                    'linestyle',opt.LINESTYLE{i},...
                    'linewidth',opt.LINEWIDTH);
            end
    end
end
hold(opt.AXIS,'off');

% extras
box(opt.AXIS,'on');
grid(opt.AXIS,'on');
axis(opt.AXIS,'tight');

% special yaxis tick labels (names)
if(~isempty(opt.NAMESONYAXIS) && any(opt.NAMESONYAXIS))
    set(opt.AXIS,'ytick',1:nrecs);
    switch opt.NAMESONYAXIS
        case {'kstnm' 'st' 'sta' 'station'}
            set(opt.AXIS,'yticklabel',kname(:,2));
        case {'stcmp'}
            kname=strcat(kname(:,2),'.',kname(:,4));
            set(opt.AXIS,'yticklabel',kname);
        case {'kname'}
            kname=strcat(kname(:,1),'.',kname(:,2),...
                '.',kname(:,3),'.',kname(:,4));
            set(opt.AXIS,'yticklabel',kname);
        otherwise
            set(opt.AXIS,'yticklabel',{data.name}.');
    end
end

% axis zooming
if(~isempty(opt.XLIM))
    %if(isempty(opt.YLIM)); axis autoy; end
    xlim(opt.AXIS,opt.XLIM);
end
if(~isempty(opt.YLIM))
    %if(isempty(opt.XLIM)); axis autox; end
    ylim(opt.AXIS,opt.YLIM);
end

% datetick
if(opt.ABSOLUTE)
    if(isempty(opt.DATEFORMAT))
        if(isempty(opt.XLIM))
            datetick(opt.AXIS,'x');
        else
            datetick(opt.AXIS,'x','keeplimits');
        end
    else
        if(isempty(opt.XLIM))
            datetick(opt.AXIS,'x',opt.DATEFORMAT);
        else
            datetick(opt.AXIS,'x',opt.DATEFORMAT,'keeplimits');
        end
    end
end

% label
if(isempty(opt.TITLE))
    opt.TITLE=[num2str(numel(goodfiles)) ...
        '/' num2str(nrecs) ' Records'];
end
if(isempty(opt.XLABEL))
    if(opt.ABSOLUTE)
        xlimits=get(opt.AXIS,'xlim');
        opt.XLABEL=joinwords(cellstr(datestr(unique(fix(xlimits)))),...
            '   to   ');
    else
        opt.XLABEL='Time (sec)';
    end
end
if(isempty(opt.YLABEL)); opt.YLABEL='Record'; end
title(opt.AXIS,opt.TITLE,'color',opt.FGCOLOR,'fontsize',opt.FONTSIZE);
xlabel(opt.AXIS,opt.XLABEL,'color',opt.FGCOLOR,'fontsize',opt.FONTSIZE);
ylabel(opt.AXIS,opt.YLABEL,'color',opt.FGCOLOR,'fontsize',opt.FONTSIZE);

% output axes if wanted
if(nargout); varargout{1}=opt.AXIS; end

end
