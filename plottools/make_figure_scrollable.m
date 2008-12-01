function make_figure_scrollable(h_fig, all_axes)
% make_figure_scrollable(fig_handle, axes_to_scroll)
%
% Adds scrollbars to the given figure window that let you zoom, pan,
% and change the color limits of all subplots at once.

% Copyright (C) 2008 Ron J. Weiss (ronw@ee.columbia.edu)
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

if nargin < 1;  h_fig = gcf;  end
if nargin < 2
  xaxes_fun = @() get_axes(h_fig, 'axes');
  all_axes = xaxes_fun();
else
  xaxes_fun = @() all_axes;
end
yaxes_fun = @() get_axes(feval(xaxes_fun), 'image');

all_image_axes = get_axes(all_axes, 'image');
all_images = findobj(all_axes, 'Type', 'image', 'Tag', '');

% Check to see if xlim, ylim, and clim are consistent across all axes.
align_x_axes = are_limits_consistent(get(all_axes, 'XLim'));
align_y_axes = are_limits_consistent(get(all_image_axes, 'YLim'));
align_c_axes = are_limits_consistent(get(all_image_axes, 'CLim'));

% Find current settings and absolute limits for xlim, ylim, and clim.
% The parsing is kind of nasty because images and 1D plots need to be
% handled differently and because the output type of get(axes) is
% different for scalar axes and array axes.
if length(all_images) > 0
  current_xlim = get(all_axes, 'XLim');
  if iscell(current_xlim)
    current_xlim = cat(1, current_xlim{:});
    current_xlim = [min(current_xlim(1,:)) max(current_xlim(2,:))];
  end
  current_ylim = get(all_image_axes, 'YLim');
  if iscell(current_ylim)
    current_ylim = cat(1, current_ylim{:});
    current_ylim = [min(current_ylim(1,:)) max(current_ylim(2,:))];
  end
  current_clim = get(all_image_axes, 'CLim');
  if iscell(current_clim)
    current_clim = cat(1, current_clim{:});
    current_clim = [min(current_clim(1,:)) max(current_clim(2,:))];
  end

  cd = get(all_images, 'CData');
  if ~iscell(cd)
    cd = {cd};
  end
  sz_x = max(cellfun(@(x) size(x, 2), cd));
  sz_y = max(cellfun(@(x) size(x, 1), cd));
  clim_min = min(cellfun(@(x) min(x(:)), cd));
  clim_max = max(cellfun(@(x) max(x(:)), cd));

  original_xlim = [min(1, current_xlim(1)) max(sz_x, current_xlim(2))];
  original_ylim = [min(1, current_ylim(1)) max(sz_y, current_ylim(2))];
  original_clim = [clim_min clim_max];
else
  yaxes_fun = xaxes_fun;
  align_c_axes = false;
  original_clim = [0 1];
  if length(all_axes) > 1
    min_x = max(cellfun(@(x) x(1), get(all_axes, 'XLim')));
    max_x = max(cellfun(@(x) x(2), get(all_axes, 'XLim')));
    original_xlim = [min_x max_x];
    min_y = max(cellfun(@(x) x(1), get(all_axes, 'YLim')));
    max_y = max(cellfun(@(x) x(2), get(all_axes, 'YLim')));
    original_ylim = [min_y max_y];
  else
    original_xlim = get(all_axes, 'XLim');
    original_ylim = get(all_axes, 'YLim');
  end
  current_xlim = original_xlim;
  current_ylim = original_ylim;
  current_clim = original_clim;
end

setup_controls(h_fig, 'XLim', original_xlim, current_xlim, ...
    xaxes_fun, align_x_axes);
setup_controls(h_fig, 'YLim', original_ylim, current_ylim, ...
    yaxes_fun, align_y_axes);
setup_controls(h_fig, 'CLim', original_clim, current_clim, ...
    yaxes_fun, align_c_axes);

% Link axes so that standard zoom/pan controls apply to all axes (but
% not colorbars).
%linkaxes(all_axes, 'xy')


function y = are_limits_consistent(lim)
y = true;
if iscell(lim) && any(cat(2, lim{:}) ~= repmat(lim{1}, [1 length(lim)]))
  y = false;
end


function setup_controls(h_fig, property, orig_lim, curr_lim, axes_fun, align_axes)
if align_axes
  % Add a scrollbar control for the given property of the given axes.
  switch lower(property(1))
    case 'x'
      hidden_panel_pos = [0.05  -1.0 0.9 0.9];
      control_location = 'Bottom';
    case 'y'
      hidden_panel_pos = [-1.0  0.05 0.9 0.9];
      control_location = 'Left';
    case 'c'
      hidden_panel_pos = [0  0.05 1.05 0.9];
      control_location = 'Right';
    otherwise
      return
  end
  
  % Create hidden panel to control scrollbar placement.
  h_hidden_panel = uipanel('Parent', h_fig, 'Tag', 'scrollbar_panel', ...
      'Units', 'normalized', 'Position', hidden_panel_pos, ...
      'Visible', 'off', 'HitTest', 'off');
  normalized_lim = (curr_lim - orig_lim(1)) / (orig_lim(2) - orig_lim(1));
  zooming_scrollbar(h_hidden_panel, normalized_lim, ...
      @(a,b,c,d) scrollbar_update_axes(a, b, c, d, property, orig_lim, ...
      axes_fun, h_fig), control_location);
  set(feval(axes_fun), property, curr_lim)
else
  % Since axes have inconsistent axes, we cannot create a single
  % scrollbar control for all of them.  Instead add simple button
  % controls that zoom and pan all axes equally.

  switch lower(property(1))
    case 'x'
      pos = [40  0 20 20];
      dim = 1;
      scroll_strings = '<>';
    case 'y'
      pos = [ 0 40 20 20];
      dim = 2;
      scroll_strings = 'v^';
    otherwise
      return
  end

  ZOOM = 0.9;
  PAN = 0.05;
  args = {property, axes_fun};
  uicontrol(h_fig, 'Style', 'pushbutton', 'String', 'R', 'Position', pos, ...
      'Callback', @(a,b) simple_reset_callback(args{:}));
  pos(dim) = pos(dim) + pos(dim+2);
  uicontrol(h_fig, 'Style', 'pushbutton', 'String', '+', 'Position', pos, ...
      'Callback', @(a,b) simple_zoom_callback(args{:}, ZOOM));
  pos(dim) = pos(dim) + pos(dim+2);
  uicontrol(h_fig, 'Style', 'pushbutton', 'String', '-', 'Position', pos, ...
      'Callback', @(a,b) simple_zoom_callback(args{:}, 1/ZOOM));
  pos(dim) = pos(dim) + pos(dim+2);
  uicontrol(h_fig, 'Style', 'pushbutton', 'String', scroll_strings(1), ...
      'Position', pos, ...
      'Callback', @(a,b) simple_scroll_callback(args{:}, -PAN));
  pos(dim) = pos(dim) + pos(dim+2);
  uicontrol(h_fig, 'Style', 'pushbutton', 'String', scroll_strings(2), ...
      'Position', pos, ...
      'Callback', @(a,b) simple_scroll_callback(args{:}, PAN));
end


function scrollbar_update_axes(h_scrollbar, h_hidden_panel, min_val, ...
    max_val, prop, original_lim, axes_fun, h_fig)
minimum = original_lim(1);
range = original_lim(2) - original_lim(1);
new_lim = [min_val max_val]*range + minimum;
new_range = new_lim(2) - new_lim(1);

all_axes = feval(axes_fun);
set(all_axes, prop, new_lim);

if strcmpi(prop, 'CLim')
  for cb_axis = findobj(h_fig, 'Tag', 'Colorbar')'
    yt = get(cb_axis, 'YTick');
    ntick = length(yt);
    yl = get(cb_axis, 'YLim');
    cb_range = yl(2) - yl(1);
  
    ytl = num2cell((yt - yl(1)) * new_range/cb_range + new_lim(1));
    for n = 1:length(ytl)
      ytl{n} = str2num(sprintf('%.2e ', ytl{n}));
    end

    set(cb_axis, 'YTickLabel', ytl);
  end
end


function simple_reset_callback(property, axes_fun)
all_axes = feval(axes_fun);
property = [property 'mode'];
for ax = all_axes(:)'
  set(ax, property, 'auto');
end


function simple_zoom_callback(property, axes_fun, zoom_factor)
all_axes = feval(axes_fun);
for ax = all_axes(:)'
  lim = get(ax, property);
  new_lim = [lim(1) ((lim(2) - lim(1))*zoom_factor + lim(1))];
  set(ax, property, new_lim);
end


function simple_scroll_callback(property, axes_fun, pan)
all_axes = feval(axes_fun);
for ax = all_axes(:)'
  lim = get(ax, property);
  new_lim = lim - (lim(1) - lim(2)) * pan;
  set(ax, property, new_lim);
end


function all_axes = get_axes(h_fig, axis_type)
all_axes = findobj(h_fig, 'Type', axis_type, 'Tag', '');
if strcmpi(axis_type, 'image')
  all_axes = get(all_axes, 'Parent');
  if iscell(all_axes)
    all_axes = cat(1, all_axes{:});
  end
end