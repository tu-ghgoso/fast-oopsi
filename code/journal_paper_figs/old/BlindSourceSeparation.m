% this script generates a simulation of a movie containing a single cell
% using the following generative model:
%
% F_t = \sum_i a_i*C_{i,t} + b + sig*eps_t, eps_t ~ N(0,I)
% C_{i,t} = gam*C_{i,t-1} + n_{i,t},      n_{i,t} ~ Poisson(lam_i*dt)
%
% where ai,b,I are p-by-q matrices.
% we let b=0 and ai be the difference of gaussians (yielding a zero mean
% matrix)
%

clear, clc,
cd /Users/joshyv/Research/projects/oopsi/fast-oopsi/code/experiments/
data_fname='/Users/joshyv/Research/projects/oopsi/fast-oopsi/data/';
fig_fname='/Users/joshyv/Research/projects/oopsi/fast-oopsi/docs/journal_paper/figs/';

% 1) generate spatial filters

% stuff required for each spatial filter
Nc      = 2;                                % # of cells in the ROI
neur_w  = 13;                               % width per neuron
width   = 20;                               % width of frame (pixels)
height  = Nc*neur_w;                        % height of frame (pixels)
Npixs   = width*height;                     % # pixels in ROI
x1      = linspace(-5,5,height);
x2      = linspace(-5,5,width);
[X1,X2] = meshgrid(x1,x2);
g1      = zeros(Npixs,Nc);
g2      = 0*g1;
Sigma1  = diag([1,1])*2;                    % var of positive gaussian
Sigma2  = diag([1,1])*3;                    % var of negative gaussian
mu      = [1 1]'*linspace(-1.2,1.2,Nc);         % means of gaussians for each cell (distributed across pixel space)
w       = Nc:-0.9:1;                          % weights of each filter

% spatial filter
for i=1:Nc
    g1(:,i)  = w(i)*mvnpdf([X1(:) X2(:)],mu(:,i)',Sigma1);
    g2(:,i)  = w(i)*mvnpdf([X1(:) X2(:)],mu(:,i)',Sigma2);
end
a_b = sum(g1-g2,2);

% 2) set simulation metadata
Sim.T       = 600;                              % # of time steps
Sim.dt      = 0.05;                            % time step size
Sim.MaxIter = 0;                                % # iterations of EM to estimate params
Sim.Np      = Npixs;                            % # of pixels in each image
Sim.w       = width;                            % width of frame (pixels)
Sim.h       = height;                           % height of frame (pixels)
Sim.Nc      = Nc;                               % # cells
Sim.plot    = 1;                                % whether to plot filter with each iteration
Sim.thresh  = 1;

% 3) initialize params
P.a     = 0*g1;
for i=1:Sim.Nc
    P.a(:,i)=g1(:,i)-g2(:,i);
end
P.b     = 0.2*sum(P.a,2);                           % baseline is zero

P.sig   = 0.05;                                 % stan dev of noise (indep for each pixel)
C_0     = 0;                                    % initial calcium
tau     = round(100*rand(Sim.Nc,1))/100+0.05;   % decay time constant for each cell
P.gam   = 1-Sim.dt./tau(1:Sim.Nc);
P.lam   = 1*ones(Sim.Nc,1);              % rate-ish, ie, lam*dt=# spikes per second
P.smooth= 0;                                    % smoothing spatial filter

% 3) simulate data
n=zeros(Sim.T,Sim.Nc);
C=n;
for i=1:Sim.Nc
    n(1,i)      = C_0;
    n(2:end,i)  = poissrnd(P.lam(i)*Sim.dt*ones(Sim.T-1,1));    % simulate spike train
    C(:,i)      = filter(1,[1 -P.gam(i)],n(:,i));               % calcium concentration
end
Z = 0*n(:,1);
F = C*P.a' + (1+Z)*P.b'+P.sig*randn(Sim.T,Npixs);               % fluorescence
F(1)=max(F(:))*1.5;

for j=1:Nc, if sum(n(:,j))==0, break, end; end

%% 4) other stuff
MakMov  = 1;
% make movie of raw data
if MakMov==1
    Sim.bits=8;
    Sim.tif_name=[data_fname 'two_overlapping_cells.tif'];
    MakeTif(F,Sim);
end

GetROI  = 0;
if GetROI>0, figure(100); clf, imagesc(reshape(sum(P.a,2),width,height)); end
if GetROI==1;
    imagesc(reshape(mean(F,1),width,height))
    for i=1:Nc
        BW = roipoly;
        cell_ind{i}=find(BW==1);
    end
    save([data_fname 'cell_ind'],'cell_ind')
else
    load([data_fname 'cell_ind'])
end

%% end-1) infer spike train using various approaches
fnum    = 0;
qs=[5 8]; %[1 2 3 4];
MaxIter=10;
for q=qs
    GG=F; Tim=Sim; Phat{q}=P; Fmean=mean(F,1)';
    if q==1,
        I{q}.label='True Filter';
        Tim.MaxIter=0;
    elseif q==2
        I{q}.label='Uniform';
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=1;
        end
        Tim.MaxIter=0;
    elseif q==3
        I{q}.label='Mean';
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=Fmean(cell_ind{j});
        end
        Tim.MaxIter=0;
    elseif q==4
        I{q}.label='MLE';
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=Fmean(cell_ind{j});
        end
        Tim.MaxIter=MaxIter;
        Tim.thresh=0;
    elseif q==5
        I{q}.label=[{'Thresholded'}; {'MLE'}];
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=Fmean(cell_ind{j});
        end
        Phat{q}.smooth=0;
        Tim.MaxIter=MaxIter;
        Tim.thresh=1;
    elseif q==6
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=Fmean(cell_ind{j});
        end
        Phat{q}.smooth=.001;
        Tim.MaxIter=MaxIter;
        Tim.thresh=1;
    elseif q==7
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=Fmean(cell_ind{j});
        end
        Phat{q}.smooth=.01;
        Tim.MaxIter=MaxIter;
        Tim.thresh=1;
    elseif q==8
        Phat{q}.a=0*P.a;
        Phat{q}.b=0*P.a(:,1);
        for j=1:Nc
            Phat{q}.a(cell_ind{j},j)=Fmean(cell_ind{j});
        end
        Phat{q}.smooth=.1;
        Tim.MaxIter=MaxIter;
        Tim.thresh=1;
    end
    if any(q==6:8),  I{q}.label=[{'Thresholded'}; {[num2str(Phat{q}.smooth) ' MAP']}]; end
    display(I{q}.label)
    tic
    [I{q}.n I{q}.P] = FOOPSI2_59(GG,Phat{q},Tim);
    toc
end

%% end) plot results
clear Pl
nrows   = 3+numel(qs);                                  % set number of rows
h       = zeros(nrows,1);
Pl.xlims= [105 500];                            % time steps to plot
Pl.nticks=10;                                    % number of ticks along x-axis
Pl.n    = double(n); Pl.n(Pl.n==0)=NaN;         % store spike train for plotting
Pl      = PlotParams(Pl);                       % generate a number of other parameters for plotting
Pl.vs   = 2;
Pl.colors(1,:) = [0 0 0];
Pl.colors(2,:) = Pl.gray;
Pl.colors(3,:) = [.5 0 0];
Pl.Nc   = Sim.Nc;
Pl.w=Sim.w;
Pl.h=Sim.h;
fnum    = 0;

fnum = figure(fnum+1); clf,

% plot fluorescence data
i=1; h(i) = subplot(nrows,1,i);
Pl.label = [{'1D'}; {'Fluorescence'}];
Pl.color = 'k';
GG=0*C;
GG(:,1)=z1(F*P.a(:,1));
GG(:,2)=z1(F*P.a(:,2));
Plot_nX(Pl,GG);
% title(I{q}.label)

% plot calcium
i=i+1; h(i) = subplot(nrows,1,i);
Pl.label = 'Calcium';
Pl.color = Pl.gray;
Plot_nX(Pl,C);

% plot spikes
i=i+1; h(i) = subplot(nrows,1,i); hold on
Pl.label = [{'Spike'}; {'Trains'}];
for j=1:Nc
    Pl.color=Pl.colors(j,:);
    Plot_n(Pl,n(:,j));
end

% plot inferred spike trains
for q=qs
    Pl.label = I{q}.label;
    i=i+1; h(i) = subplot(nrows,1,i); hold on
    Plot_nn(Pl,I{q}.n);
end

% set xlabel stuff
subplot(nrows,1,nrows)
set(gca,'XTick',Pl.XTicks,'XTickLabel',Pl.XTicks*Sim.dt,'FontSize',Pl.fs)
xlabel('Time (sec)','FontSize',Pl.fs)
linkaxes(h,'x')

% print fig
wh=[7 5];   %width and height
set(fnum,'PaperPosition',[0 11-wh(2) wh]);
print('-depsc',[fig_fname 'Multi_Spikes'])

%% plot true filters, svd's, and estimated filters
fnum=fnum+1; figure(fnum), clf,

mn(1) = min([min(P.a) min(P.b)]);
mx(1) = (max([max(P.a) max(P.b)])-mn(1))/60;

for q=qs
    mn(1+q) = min(Phat{q}.a(:));
    mx(1+q) = (max(Phat{q}.a(:))-mn(1))/60;
end

mnn=min(mn);
mxx=max(mn);

nrows=numel(qs);
ncols=3;

j=0;
for q=qs
    j=j+1;
    subplot(nrows,ncols,1+(j-1)*ncols),
    Pl.ylab=I{q}.label;
    if j==1, Pl.tit='Sum of Filters'; else Pl.tit=[]; end
    Plot_im(Pl,sum(I{q}.P.a,2))
end

for i=1:Nc, 
    j=0;
    for q=qs
        j=j+1;
        subplot(nrows,ncols,i+1+(j-1)*ncols),
        Pl.ylab=[];
        if j==1,  Pl.tit=['Filter ' num2str(i)]; else Pl.tit=[]; end
        Plot_im(Pl,(I{q}.P.a(:,i)-mn(q+1))/mx(q+1))
    end
end
set(gca,'XTick',[0:5:25],'YTick',[0:5:25])

% print fig
wh=[7 5];   %width and height
set(fnum,'PaperPosition',[0 11-wh(2) wh]);
print('-depsc',[fig_fname 'est_filers'])

%%
fnum=fnum+1; figure(fnum), clf,

j=0; ncols=1; nrows=numel(qs);
for q=qs
    j=j+1;
    subplot(nrows,ncols,j),
    plot(I{q}.P.l)
end
wh=[7 5];   %width and height
set(fnum,'PaperPosition',[0 11-wh(2) wh]);
print('-depsc',[fig_fname 'lik'])