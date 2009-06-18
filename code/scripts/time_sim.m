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

clear,clc

% 1) generate spatial filters

% % stuff required for each spatial filter
Nc      = 1;                                % # of cells in the ROI
neur_w  = 1;                               % width per neuron
width   = 1;                               % width of frame (pixels)
height  = Nc*neur_w;                        % height of frame (pixels)
Npixs   = width*height;                     % # pixels in ROI

% 2) set simulation metadata
Sim.dt      = 0.005;                            % time step size
Sim.MaxIter = 0;                                % # iterations of EM to estimate params
Sim.Np      = Npixs;                            % # of pixels in each image
Sim.w       = width;                            % width of frame (pixels)
Sim.h       = height;                           % height of frame (pixels)
Sim.Nc      = Nc;                               % # cells
Sim.plot    = 0;                                % whether to plot filter with each iteration

lam         = [10; 500];
sigs        = [1/4 8];
% 3) initialize params
P.a     = 1;
P.b     = 0;                           % baseline is zero

P.sig   = 0.25;                                 % stan dev of noise (indep for each pixel)
C_0     = 0;                                    % initial calcium
tau     = [.1 .5]; %round(100*rand(Sim.Nc,1))/100+0.05;   % decay time constant for each cell
P.gam   = 1-Sim.dt./tau(1:Sim.Nc);
dim     = 5;
% stim    = rand(Sim.T,dim)'*2;
P.lam   = 10; %sin(linspace(0,pi,dim))';


% 3) simulate data
for tt=1:5
    disp(['tt', num2str(tt)])
    T=200*2.^(0:7);
    for q=1:length(T)
        disp(['q', num2str(q)])
        Sim.T = T(q);
        n=zeros(Sim.T,Sim.Nc);
        C=n;
        n(1)      = C_0;
        n(2:end)  = poissrnd(P.lam*Sim.dt*ones(1,Sim.T-1));    % simulate spike train
        C         = filter(1,[1 -P.gam],n);               % calcium concentration
        F = C*P.a' + P.b'+P.sig*randn(Sim.T,Npixs);               % fluorescence

        D{q}.n=n; D{q}.C=C; D{q}.F=F;

        %% infer spikes
        GG=D{q}.F; Tim=Sim;
        Phat{q}=P;
        I{q}.label='True Filter';
        display(I{q}.label)
        tic
        I{1,q,tt}.n = FOOPSI_v3_05_01(GG',Phat{q},Tim);
        I{1,q,tt}.time = toc;

        tic
        I{2,q,tt}.n = WienerFilt1_2(F,Sim.dt,P);
        I{2,q,tt}.time = toc;

        I{3,q,tt}.n = I{2,q}.n; I{3}.n(I{3,q}.n<0)=0;
        I{3,q,tt}.time = toc;

        tic
        I{4,q,tt}.n = [diff(F); 0];
        I{4,q,tt}.time = toc;


    end
end

for q=1:length(T)
    for i=1:4
        for tt=1:5
            time_vec(tt)=I{i,q,tt}.time;
        end
        mean_time(i,q)=mean(time_vec);
        std_time(i,q)=std(time_vec);
        var_time(i,q)=var(time_vec);

    end
end

save('../../data/time_stuff.mat')

%% end) plot results
clear Pl
nrows   = 1;
ncols   = 1;
h       = zeros(nrows,1);
Pl.xlims= [5 Sim.T-101];                            % time steps to plot
Pl.nticks=5;                                    % number of ticks along x-axis
Pl.n    = double(n); Pl.n(Pl.n==0)=NaN;         % store spike train for plotting
Pl      = PlotParams(Pl);                       % generate a number of other parameters for plotting
Pl.vs   = 4;
Pl.colors(1,:) = [0 0 0];
Pl.colors(2,:) = Pl.gray;
Pl.colors(3,:) = [.5 0 0];
Pl.Nc   = Sim.Nc;
fnum = figure(1); clf,
Pl.interp = 'latex';


subplot(nrows,ncols,nrows*ncols)
errorbar(mean_time(1:4,:)',std_time(1:4,:)')
set(gca,'YScale','log') %,'YTick',10.^(-5:10),'XTickLabel',[]);

ymax=max(mean_time(:)+std_time(:));
ymin=max(10^-5,min(mean_time(:)-std_time(:)));
axis([.9 8.1 ymin ymax])
% set(gca,'YTick',linspace(mink,maxk,5),'YTickLabel',0:5)
set(gca,'XTickLabel',T)
set(gca,'YTick',10.^(-5:5),'YTickLabel',10.^(-5:5))
xlabel('Number of Time Steps','FontSize',Pl.fs)
ylab=ylabel([{'Computational'}; {'Time'}],'Interpreter','none','FontSize',Pl.fs);
set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')



% % print fig
% wh=[7 5];   %width and height
% DirName = '../../figs/';
% FileName = 'time_sim';
% PrintFig(wh,DirName,FileName);