function Plot_n_MAP(Pl,n)

cla, hold on
n(abs(n)<1e-3)=NaN;                             % set negligible values to NaN so they are not plotted
stem(Pl.n,'Marker','v','MarkerSize',Pl.vs,...   % plot real spike train
    'LineStyle','none','MarkerFaceColor','k','MarkerEdgeColor','k');

pos = find(n>0);                                % plot positive spikes in blue
stem(pos,n(pos),'Marker','none','LineWidth',Pl.sw,'Color',Pl.col(2,:))
neg = find(n<=0);                               % plot negative spikes in red
stem(neg,n(neg),'Marker','none','LineWidth',Pl.sw,'Color',Pl.col(1,:))

axis([Pl.xlims min(n) max(max(n), max(Pl.n))])
ylab=ylabel(Pl.label,'Interpreter',Pl.inter,'FontSize',Pl.fs);
set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')
set(gca,'YTick',0:1,'YTickLabel',[])
set(gca,'XTick',Pl.XTicks,'XTickLabel',[])
set(gca,'XTickLabel',[])
box off