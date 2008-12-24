function Plot_n(Pl,n)

stem(n,'Marker','none','LineWidth',Pl.sw,'Color',Pl.gray,'MarkerFaceColor',Pl.gray,'MarkerEdgeColor',Pl.gray);
ylab=ylabel([{'Spike'}; {'Train'}],'Interpreter',Pl.inter,'FontSize',Pl.fs);
set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')
set(gca,'YTick',[],'YTickLabel',[])
set(gca,'XTick',Pl.XTicks,'XTickLabel',[],'FontSize',Pl.fs)
axis([Pl.xlims 0 max(n(Pl.xlims(1):Pl.xlims(2)))])
% axis([Pl.xlims 0 max(n(Pl.xlims(1):Pl.xlims(2)))])
box off