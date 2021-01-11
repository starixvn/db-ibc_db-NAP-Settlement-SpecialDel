/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Intg_Summarize_VendorRNG_ByRefNo_Void14_tmp]
	@TVP_SummarizeRNG [TVP_SummarizeRNG] READONLY,
	@ErrCode_ByRefNo int = -1 OUTPUT,
	@ErrMsg_ByRefNo nvarchar(200) = '' OUTPUT
AS
BEGIN
/*
Creator : Helen
Date : 20200107
Task : Settlement VendorRNG
DB: DBTXN/bodb02

Revisions:
	--20200107@Helen: Support to void ticket in bettransRnG14 for Roulette - clone from Dot_Intg_Summarize_VendorRNG_ByRefNo - [148359]
	
*/
	set nocount on;

	declare @refNo bigint
	declare @IsJPContribution bit -- 0: non jp contribution bettype , 1: contribution bettype 
	declare @refNobettype smallint  
	set @IsJPContribution = 0 
    select top 1 @refNo = refNo From @TVP_SummarizeRNG
    
    select @refNobettype = bettype from bettrans14 with(nolock) where transid = @refNo
    
    if (@refNobettype in ( 2198,2398,2998,4297 )) --ONERng:2198,2398,2998 / PP:4297
     begin 
		set @IsJPContribution = 1
     end 
    
    

	declare 
		@rollback tinyint, @sumStake money, @sumActual_stake money,
		@sumWinlost money, @sumAwinlost money, @sumMwinlost money, @sumSwinlost money,
		@sumPlayercomm money, @sumComm money, @sumAcomm money, @sumScomm money,
		@avgApositiontaking smallmoney, @avgMpositiontaking smallmoney, @avgSpositiontaking smallmoney, @avgTpositiontaking smallmoney,
		@avgPlayerdiscount decimal(9, 8), @avgDiscount decimal(9, 8), @avgAdiscount decimal(9, 8), @avgSdiscount decimal(9, 8),
		@refno2 bigint,@avgContributionRate decimal(9,8),@sumBetStake money,@sumContributionStake3rd decimal(19, 8), @avgEpositiontaking smallmoney
	--SUM : winlost/comm
	select
		@sumStake = sum(br.Stake), @sumActual_stake = sum(br.Actual_stake), 
		@sumWinlost = sum(br.Winlost), @sumAwinlost = sum(br.Awinlost), @sumMwinlost = sum(br.Mwinlost), @sumSwinlost = sum(br.Swinlost),
		@sumPlayercomm = sum(br.Playercomm), @sumComm = sum(br.Comm), @sumAcomm = sum(br.Acomm), @sumScomm = sum(br.Scomm),
		@sumBetStake = isnull(sum(br.BetStake), 0), @sumContributionStake3rd = isnull(sum(br.ContributionStake3rd), 0)
	from 
		BettransRNG14 br with (nolock) inner join @TVP_SummarizeRNG bs
		on br.Transid = bs.transid and br.RefNo = bs.refno
	--AVG : pt/discount
	if (@IsJPContribution = 0 )
		begin 	
			select
				@avgApositiontaking = avg(br.apositiontaking), @avgMpositiontaking = avg(br.mpositiontaking), @avgSpositiontaking = avg(br.spositiontaking), @avgTpositiontaking = avg(br.tpositiontaking),
				@avgPlayerdiscount = avg(br.playerdiscount), @avgDiscount = avg(br.discount), @avgAdiscount = avg(br.adiscount), @avgSdiscount = avg(br.sdiscount),
				@refno2 = isnull(avg(br.refno2), 0), @avgContributionRate = isnull(avg(br.ContributionRate), 0), @avgEpositiontaking = avg(br.epositiontaking)
			from 
				BettransRNG14 br with (nolock) 
			where
				br.RefNo = @refNo
				and br.StatusID in (111, 112, 113, 103, 102, 101)--111:DRAW/112:WON/113:LOSE/103:Refund/102:Void/101:Reject
		end 
	else
		begin 
			select
				@avgApositiontaking = ISNULL(avg(br.apositiontaking), 0), @avgMpositiontaking = ISNULL(avg(br.mpositiontaking), 0), @avgSpositiontaking = ISNULL(avg(br.spositiontaking), 0), @avgTpositiontaking = ISNULL(avg(br.tpositiontaking), 0),
				@avgPlayerdiscount = ISNULL(avg(br.playerdiscount), 0), @avgDiscount = ISNULL(avg(br.discount), 0), @avgAdiscount = ISNULL(avg(br.adiscount), 0), @avgSdiscount = ISNULL(avg(br.sdiscount), 0),
				@refno2 = isnull(avg(br.refno2), 0), @avgContributionRate = isnull(avg(br.ContributionRate), 0), @avgEpositiontaking = avg(br.epositiontaking)
			from 
				BettransRNG14 br with (nolock) 
			where
				br.RefNo = @refNo
				and br.StatusID in (111, 112, 113)--111:DRAW/112:WON/113:LOSE
		end 

	if(@sumActual_stake > @sumWinlost)
	begin try
		--Case : Lost
		--update bettrans
		update bettrans14 with (rowlock, updlock) set 
			ruben = 1,
			stake += @sumStake,
			actual_stake += @sumActual_stake,
			winlost += @sumWinlost,
			awinlost += @sumAwinlost,
			mwinlost += @sumMwinlost,
			swinlost += @sumSwinlost,
			playercomm += @sumPlayercomm,
			comm += @sumComm,
			acomm += @sumAcomm,
			scomm += @sumScomm,
			apositiontaking = @avgApositiontaking,
			mpositiontaking = @avgMpositiontaking,
			spositiontaking = @avgSpositiontaking,
			tpositiontaking = @avgTpositiontaking,
			playerdiscount = @avgPlayerdiscount,
			discount = @avgDiscount,
			adiscount = @avgAdiscount,
			sdiscount = @avgSdiscount,
			[status] = case when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) > 0 then 'WON' 
							when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) = 0 then 'DRAW' 
							else 'LOSE' end,
			statusID = case when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) > 0 then 112 
							when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) = 0 then 111 
							else 113 end,
			odds = case when @refno2 > 0 then @avgContributionRate else bt.odds end,
			oddsspread = ISNULL(oddsspread, 0) + @sumBetStake,
			betid = ISNULL(betid, 0) + @sumContributionStake3rd * 100000000,
			epositiontaking = @avgEpositiontaking
		from bettrans14 bt
		where transid = @refNo

		select @rollback = 1

		--update isSum=1
		update BettransRNG14 with (rowlock, updlock)
		set isSum = 1
		from BettransRNG14 br inner join @TVP_SummarizeRNG bs
		on br.Transid = bs.transid and br.RefNo = bs.refno

		--select @rollback = 2
	end try
	begin catch
		if(@rollback = 1)
		begin
			--rollback bettrans14 AVG
			select
				@avgApositiontaking = isnull(avg(br.apositiontaking), 0), @avgMpositiontaking = isnull(avg(br.mpositiontaking), 0), @avgSpositiontaking = isnull(avg(br.spositiontaking), 0), @avgTpositiontaking = isnull(avg(br.tpositiontaking), 0),
				@avgPlayerdiscount = isnull(avg(br.playerdiscount), 0), @avgDiscount = isnull(avg(br.discount), 0), @avgAdiscount = isnull(avg(br.adiscount), 0), @avgSdiscount = isnull(avg(br.sdiscount), 0),
				@refno2 = isnull(avg(br.refno2), 0), @avgContributionRate = isnull(avg(br.ContributionRate), 0), @avgEpositiontaking = avg(br.epositiontaking)
			from 
				BettransRNG14 br with (nolock) 
			where
				br.RefNo = @refNo and br.isSum = 1

			update bettrans14 with (rowlock, updlock) set 
			    ruben = case when actual_stake -@sumActual_stake=0 then 0 else 1 end,
				stake -= @sumStake,
				actual_stake -= @sumActual_stake,
				winlost -= @sumWinlost,
				awinlost -= @sumAwinlost,
				mwinlost -= @sumMwinlost,
				swinlost -= @sumSwinlost,
				playercomm -= @sumPlayercomm,
				comm -= @sumComm,
				acomm -= @sumAcomm,
				scomm -= @sumScomm,
				apositiontaking = @avgApositiontaking,
				mpositiontaking = @avgMpositiontaking,
				spositiontaking = @avgSpositiontaking,
				tpositiontaking = @avgTpositiontaking,
				playerdiscount = @avgPlayerdiscount,
				discount = @avgDiscount,
				adiscount = @avgAdiscount,
				sdiscount = @avgSdiscount,
				[status] = case when  actual_stake -@sumActual_stake=0 then 'running'
				                when ((bt.winlost - @sumWinlost) - (bt.actual_stake - @sumActual_stake)) > 0 then 'WON' 
								when ((bt.winlost - @sumWinlost) - (bt.actual_stake - @sumActual_stake)) = 0 then 'DRAW' 
								else 'LOSE' end,
				statusID = case when  actual_stake -@sumActual_stake=0 then 0
				                when ((bt.winlost - @sumWinlost) - (bt.actual_stake - @sumActual_stake)) > 0 then 112 
								when ((bt.winlost - @sumWinlost) - (bt.actual_stake - @sumActual_stake)) = 0 then 111 
								else 113 end,
				odds = case when @refno2 > 0 then @avgContributionRate else bt.odds end,				
				oddsspread -= @sumBetStake,
				betid -= @sumContributionStake3rd * 100000000,
				epositiontaking = @avgEpositiontaking
			from bettrans14 bt
			where transid = @refNo
		end
	end catch
	else
	begin try
		--Case : Win/Draw
		--update isSum=1
		update BettransRNG14 with (rowlock, updlock)
		set isSum = 1
		from BettransRNG14 br inner join @TVP_SummarizeRNG bs
		on br.Transid = bs.transid and br.RefNo = bs.refno

		select @rollback = 3

		--update bettrans	
		update bettrans14 with (rowlock, updlock) set 
			ruben = 1,
			stake += @sumStake,
			actual_stake += @sumActual_stake,
			winlost += @sumWinlost,
			awinlost += @sumAwinlost,
			mwinlost += @sumMwinlost,
			swinlost += @sumSwinlost,
			playercomm += @sumPlayercomm,
			comm += @sumComm,
			acomm += @sumAcomm,
			scomm += @sumScomm,
			apositiontaking = @avgApositiontaking,
			mpositiontaking = @avgMpositiontaking,
			spositiontaking = @avgSpositiontaking,
			tpositiontaking = @avgTpositiontaking,
			playerdiscount = @avgPlayerdiscount,
			discount = @avgDiscount,
			adiscount = @avgAdiscount,
			sdiscount = @avgSdiscount,
			[status] = case when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) > 0 then 'WON' 
							when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) = 0 then 'DRAW' 
							else 'LOSE' end,
			statusID = case when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) > 0 then 112 
							when ((bt.winlost + @sumWinlost) - (bt.actual_stake + @sumActual_stake)) = 0 then 111 
							else 113 end,
			odds = case when @refno2 > 0 then @avgContributionRate else bt.odds end,
			oddsspread = ISNULL(oddsspread, 0) + @sumBetStake,
			betid = ISNULL(betid, 0) + @sumContributionStake3rd * 100000000,
			epositiontaking = @avgEpositiontaking
		from bettrans14 bt
		where transid = @refNo

		--select @rollback = 4
	end try
	begin catch
		if(@rollback = 3)
		begin
			--rollback BettransRNG.isSum=1
			update BettransRNG14 with (rowlock, updlock)
			set isSum = 0
			from BettransRNG14 br inner join @TVP_SummarizeRNG bs
			on br.Transid = bs.transid and br.RefNo = bs.refno
		end
	end catch

	select @ErrCode_ByRefNo = 0, @ErrMsg_ByRefNo = 'V_' + isnull(cast(@refNo as varchar), 0)
END



GO


