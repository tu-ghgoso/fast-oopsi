

% 1) get data
clear, clc, %close all
foldname    = 'TS193_3';
dir         = ['/Users/joshyv/Research/oopsi/meta-oopsi/data/karel/takashi/'];
im_dir      = '/Image/';
phys_dir    = '/Physiology/';
i           = 2;
LoadTif     = 1;
if i<10                                         % get tif file name
    tifname=[dir foldname im_dir  foldname '_00' num2str(i) '.tif'];
    matname = [foldname '_00' num2str(i) '.mat'];
else
    tifname=[dir foldname im_dir  foldname '_0' num2str(i) '.tif'];
    matname = [foldname '_0' num2str(i) '.mat'];
end


if LoadTif == 1                                     % get whole movie
    MovInf  = imfinfo(tifname);                     % get number of frames
    Meta.T       = numel(MovInf)/2;                  % only alternate frames have functional data
    DataMat = zeros(MovInf(1).Width*MovInf(1).Height,Meta.T);% initialize mat to store movie
    for j=1:2:Meta.T*2
        X = imread(tifname,j);
        DataMat(:,(j+1)/2)=X(:);
    end

    % manually select ROI
    MeanFrame=mean(DataMat');
    figure(100), clf,
    imagesc(reshape(z1(MeanFrame),MovInf(1).Height,MovInf(1).Width))
    title('select corners, starting top-left, going clock wise')
    [x y]   = ginput(4);
    ROWS    = [round(mean(y(1:2))) round(mean(y(3:4)))];                              % define ROI
    COLS    = [round(mean(x([1 4]))) round(mean(x(2:3)))];

    Meta.w=diff(ROWS)+1;
    Meta.h=diff(COLS)+1;
    ind=zeros(Meta.w*Meta.h,1);
    j=0;
    for r=1:Meta.w
        for c=1:Meta.h
            j=j+1;
            ind(j)=MovInf(1).Height*(COLS(1)-1+c)+ROWS(1)+r-1;
        end
    end

    F = DataMat(ind,:)';
    FF = uint8(F);
    for t=1:Meta.T
        if t==1, mod='overwrite'; else mod='append'; end
        imwrite(reshape(FF(t,:),Meta.h,Meta.w)',[matname(1:end-4) '.tif'],'tif','Compression','none','WriteMode',mod)
    end

    load(['/Users/joshyv/Research/oopsi/fast-oopsi/data/' matname])
    Meta.spt = R.spt;
    Meta.dt  = 30/Meta.T;
    save(matname,'F','Meta')
else
    load(matname)
end

%% 2) set simulation metadata
Meta.MaxIter = 25;                               % # iterations of EM to estimate params
Meta.Np      = Meta.w*Meta.h;                     % # of pixels in each image
Meta.matname = matname;

User.Nc      = 1;                               % # cells
User.Plot    = 1;                               % whether to plot filter with each iteration
User.Thresh  = 1;


[U,S,V] = svd(F,0);
P.a = V(:,1);
if max(F*P.a)<0, P.a=-P.a; end

%% 3) infer spike train using various approaches
P.b = 0*P.a; %(0*P.a+1)/norm(P.a);
P.sig = 0.001;
P.lam = 1/30;
P.gam=0.96;
P.smooth=0;

qs=3;%1:3;
MaxIter=24;
for q=qs
    GG=F; Tim=Meta; Phat{q}=P;
    %     if q==1,                        % estimate spatial filter from real spikes
    %         SpikeFilters;
    %     elseif q==3                     % denoising using SVD of an ROI around each cell, and using first SVD's as filters
    %         ROI_SVD_Filters;
    %     elseif q==4                     % denoising using mean of an ROI around each cell
    %         ROI_mean_Filters;
    %     elseif q==6                     % infer spikes from d-r'ed data
    %         d_r_smoother_Filter;
    if q==1,
        I{q}.label='Initial Parameters';
        User.MaxIter=0;
%         Phat{q} = FastParams4_1(GG,Meta);
    elseif q==2
        User.MaxIter=MaxIter;
        I{q}.label='Estimate Parameters';
    elseif q==3
        GG = F-repmat(mean(F),Meta.T,1);
        User.MaxIter=MaxIter;
        I{q}.label='Mean Substracted';
    elseif q==4
        P.a=mean(F);
        User.MaxIter=0;
        I{q}.label='Mean Spatial Filter';        
    elseif q==5,
        [U,S,V] = svd(F-repmat(mean(F),Meta.T,1),0);
        PCs = 1:3;
        GG = U(:,PCs)*S(PCs,PCs)*V(:,PCs)';
        I{q}.label='Denoised Substracted';
    end
    display(I{q}.label)
    [I{q}.n I{q}.P] = FOOPSI_v3_02_02(GG,Phat{q},Tim,User);
end

%% 5) plot results
clear Pl
ncols   = 3;                                  % set number of rows
nrows   = numel(qs);
h       = zeros(nrows,1);
Pl.xlims= [5 Meta.T-30];                            % time steps to plot
Pl.nticks=5;                                    % number of ticks along x-axis
n       = zeros(Meta.T,1); n(Meta.spt)=1;
Pl.n    = double(n); Pl.n(Pl.n==0)=NaN;         % store spike train for plotting
Pl      = PlotParams(Pl);                       % generate a number of other parameters for plotting
Pl.vs   = 2;
Pl.colors(1,:) = [0 0 0];
Pl.colors(2,:) = Pl.gray;
Pl.colors(3,:) = [.5 0 0];
Pl.Nc   = User.Nc;
Pl.XTicks=[100:100:Meta.T];

fnum=figure(1); clf
for q=qs

    % plot spatial filter
    i=1; h(i) = subplot(nrows,ncols,i);
    imagesc(reshape(Phat{q}.a,Meta.h,Meta.w)),
%     title(I{q}.label)
%     if q==1,
%         ylab=ylabel([{'Spatial'}; {'Filter'}]);
%         set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')
%     else
%         set(gca,'XTick',[],'YTick',[])
%     end
    colormap('gray')
    title('Spatial Filter','FontSize',Pl.fs)
    
    % plot fluorescence data
    i=i+nrows; h(i) = subplot(nrows,ncols,i);
    Pl.color = 'k';
    if q==1, Pl.label=[{'Fluorescence'}; {'Projection'}];
    else Pl.label=[]; end
    Plot_nX(Pl,F*Phat{q}.a);
    title(['Fluorescence Projection'],'FontSize',Pl.fs);
    set(gca,'XTick',Pl.XTicks,'XTickLabel',(Pl.XTicks)*Meta.dt,'FontSize',Pl.fs)
    xlabel('Time (sec)','FontSize',Pl.fs)
    
    % plot inferred spike trains
    if q==1, Pl.label = [{'Fast'}; {'Filter'}];
    else Pl.label=[]; end
    i=i+nrows; h(i) = subplot(nrows,ncols,i);
    Pl.col(2,:)=[0 0 0];
    Pl.gray=[.5 .5 .5];
    hold on
    Plot_n_MAP(Pl,I{q}.n);
    title('Infered Spike Train','FontSize',Pl.fs)

    % set xlabel stuff
    subplot(nrows,ncols,i)
    set(gca,'XTick',Pl.XTicks,'XTickLabel',(Pl.XTicks)*Meta.dt,'FontSize',Pl.fs)
    xlabel('Time (sec)','FontSize',Pl.fs)
    %     linkaxes(h,'x')
end

%% print fig
wh=[7 2];   %width and height
DirName = '../../docs/journal_paper/figs/';
FileName = 'spatial_data';
PrintFig(wh,DirName,FileName);