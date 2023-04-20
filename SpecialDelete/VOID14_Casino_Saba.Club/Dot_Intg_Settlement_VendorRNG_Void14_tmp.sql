/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Intg_Settlement_VendorRNG_Void14_tmp]
	@transid_rng bigint,	
	@custid int,
	@productID smallint,
	@gameID smallint,
	@odds smallmoney, 
	@stake money,	--actual_stake
	@payout money,
	@statusID tinyint,
	@settleTime3rd datetime = null,
	@winlostdate smalldatetime,
	@ErrCode int = -1 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@transid_jpwin bigint = 0,  
	@jackpotwin money = 0,
	@isjpgame bit = 0
AS

/*
Creator : Helen
Date : 20200107
Task : Settlement VendorRNG
DB: DBTXN/bodb02

Revisions:
	--20200107@Helen: Support to void ticket in bettransRnG14 for Roulette - clone from Dot_Intg_Settlement_VendorRNG - [148359]
	- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
*/
BEGIN
	set nocount on;

	declare		
		@db_productID int, @db_gameID int, @db_odds smallmoney, @db_Status nvarchar(10), @db_refno bigint, @db_stake money, @db_actual_stake money,
		@db_WinLost money, @db_aWinLost money, @db_mWinLost money, @db_sWinLost money, @db_PlayerComm money, @db_Comm money, @db_aComm money, @db_sComm money,
		@status nvarchar(10), @refno bigint, @WinLost money, @aWinLost money, @mWinLost money, @sWinLost money, @PlayerComm money, @Comm money, @aComm money, @sComm money,
		@username nvarchar(50), @transdate datetime, @transdesc nvarchar(1000), @actualRate float, @virtualRate float, @recommend int, @mrecommend int, @srecommend int,
		@betFrom nvarchar(4), @currency tinyint, @currencyName nvarchar(50), @ip nvarchar(15), @isSum bit, @db_JackpotInfo varchar(50),
		@refno2 bigint, @db_BetStake money, @db_ContributionStake3rd decimal(19, 8), @db_BetStake_contri money, @db_ContributionStake3rd_contri decimal(19, 8),@db_refno_contri bigint,
		@db_WinLost_contri money, @db_aWinLost_contri money,@db_mWinLost_contri money,@db_sWinLost_contri money, @refno_refund_contri bigint, @db_gameID_contri smallint,@db_transdesc_contri nvarchar(1000),
		@db_isSum_contri bit, @3rdCommShareRate smallmoney, @3rdInsuranceShareRate smallmoney
		
	set @winlostdate = convert(varchar(10), @winlostdate, 120)

	if (@statusID = 112 or @statusID=113)--112:WON/113:LOSE
	begin
		select @db_odds = odds, @db_stake = stake,@db_actual_stake = actual_stake,
			   @db_productID = Productid, @db_gameID = gameID,
			   @ErrCode = case when @odds <> @db_odds then 102
							   when @stake <> @db_actual_stake then 103 
							   when @productID <> @db_productID then 104 
							   when @gameID <> @db_gameID then 105 
							   else 0 end,
			   @ErrMsg = case @ErrCode when 102 then 'odds different'
									   when 103 then 'stake different'
									   when 104 then 'productID different'
									   when 105 then 'gameID different'
									   else 'success' end,
			   @status = case @statusID when 112 then 'WON' else 'LOSE' end,
			   @WinLost = @payout,
			   @aWinLost = case @statusID when 112 then (@payout - actual_stake) * -apositiontaking else -(@payout-actual_stake) * apositiontaking end,
			   @mWinLost = case @statusID when 112 then (@payout - actual_stake) * -mpositiontaking else -(@payout-actual_stake) * mpositiontaking end,
			   @sWinLost = case @statusID when 112 then (@payout - actual_stake) * -spositiontaking else -(@payout-actual_stake) * spositiontaking end,
			   @PlayerComm = playerdiscount * stake,
			   @Comm	   = discount * stake * (1 - apositiontaking),
			   @aComm	   = adiscount * stake * (1 - (mpositiontaking + apositiontaking)),
			   @sComm	   = sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)),
               @username = Username,
               @transdate = transdate,
			   @db_refno = RefNo, 
			   @db_WinLost = winlost,
			   @db_aWinLost = awinlost,
			   @db_mWinLost = mwinlost,
			   @db_sWinLost = swinlost,
			   @db_PlayerComm = playercomm,
			   @db_Comm = comm,
			   @db_aComm = acomm,
			   @db_sComm = scomm,
               @db_Status= [status],
               @transdesc = transdesc,
			   @isSum = isSum,
			   @refno2 = ISNULL(refno2,0),
			   @db_BetStake = BetStake, 
			   @db_ContributionStake3rd = ContributionStake3rd,
			   @db_JackpotInfo = JackpotInfo
		from BettransRNG14 with (nolock)
		where Transid = @transid_rng and statusID in (0, 112, 113, 111)
	end

	if (@statusID = 102 or @statusID = 103 or @statusID = 111 or @statusID = 101)--102:VOID/103:Refund/111:DRAW/101:Reject
	begin
		select @db_odds = odds, @db_stake = stake,@db_actual_stake = actual_stake,
			   @db_productID = ProductID, @db_gameID = gameID,
			   @ErrCode = case when @odds <> @db_odds then 102
							   when @stake <> @db_actual_stake then 103
							   when @productID <> @db_productID then 104
							   when @gameID <> @db_gameID then 105 
							   else 0 end,
			   @ErrMsg = case @ErrCode when 102 then 'odds different'
									   when 103 then 'stake different'
									   when 104 then 'productID different'
									   when 105 then 'gameID different'
									   else 'success' end,
			   @status = case @statusID when 102 then 'Void' 
			                            when 103 then 'Refund' 
										when 101 then 'Reject' 
										else 'DRAW' end,
			   @WinLost = actual_stake,
			   @aWinLost = 0,
			   @mWinLost = 0,
			   @sWinLost = 0,
			   @PlayerComm = case @statusID when 111 then playerdiscount * stake else 0 end,
			   @Comm = case @statusID when 111 then discount * stake * (1 - apositiontaking) else 0 end,
			   @aComm = case @statusID when 111 then adiscount * stake * (1 - (mpositiontaking + apositiontaking)) else 0 end,
			   @sComm = case @statusID when 111 then sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) else 0 end,			  
               @username = Username,
               @transdate = transdate,
			   @db_refno = RefNo,
			   @db_WinLost = winlost,
			   @db_aWinLost = awinlost,
			   @db_mWinLost = mwinlost,
			   @db_sWinLost = swinlost,
			   @db_PlayerComm = playercomm,
			   @db_Comm = comm,
			   @db_aComm = acomm,
			   @db_sComm = scomm,
               @db_Status= [status],
               @transdesc = transdesc,
			   @isSum = isSum,
			   @db_JackpotInfo = JackpotInfo,
			   @refno2 = ISNULL(refno2,0),
			   @db_BetStake = BetStake, 
			   @db_ContributionStake3rd = ContributionStake3rd
		from BettransRNG14 with (nolock)
		where Transid = @transid_rng
	end

	if (isnull(@ErrCode,-1) = -1)
	begin
		select  @ErrCode = 101,
				@ErrMsg = 'No ticket log.'
		select @ErrCode as ErrCode, @ErrMsg as ErrMsg
		return
	end
	else
	begin
		if (@ErrCode <> 0)
		begin
			select @ErrCode as ErrCode, @ErrMsg as ErrMsg 
			return
		end

		-------------------------------------------------------------
		---        CAPTURE value BALANCE before settlement        ---
		---------------------------VVVV------------------------------
		declare @BalanceBefore money = 0, @BalanceAfter money = 0
		
		--get ticketinfo from bettrans14 jackpot bet type
		select
			@BalanceBefore = (br.winlost - br.actual_stake + br.playercomm),
			@actualRate = bt.actualrate, @virtualRate = bt.virtualRate,
			@recommend = bt.recommend, @mrecommend = bt.mrecommend, @srecommend = bt.srecommend,
			@betFrom = bt.betFrom, @currency = bt.currency, @currencyName = bt.currencyName, @ip = bt.ip,
			@3rdCommShareRate = bt.modds, @3rdInsuranceShareRate = bt.hdp2
		from bettrans14 bt with (nolock) inner join BettransRNG14 br with (rowlock)
		on bt.transid = br.RefNo
		and br.Transid = @transid_rng

		exec Dot_Intg_SummaryRefNo_Retrieve_Void14_tmp
			@custId = @custid,
			@betTypeId = @gameID,
			@winloseDate = @winlostdate,
			@sportTypeId = @productID,
			@actualRate = @actualRate,
			@virtualRate = @virtualRate,
			@recommend = @recommend,
			@mrecommend = @mrecommend,
			@srecommend = @srecommend,
			@betFrom = @betFrom,
			@currency = @currency,
			@currencyName = @currencyName,
			@ip = @ip,
			@transdesc = @transdesc,
			@userName = @username,
			@3rdCommShareRate = @3rdCommShareRate,
			@3rdInsuranceShareRate = @3rdInsuranceShareRate,
			@refNo = @refno OUTPUT--get new RefNo if cross-day settled
			
		if(@statusID = 102 or @statusID = 103 or @statusID = 101)--102:VOID/103:Refund/101:Reject
        begin
			insert into zzzbettrans
			(transid, custid, transdate, oddsid, odds, stake, [status], creator, refno, winlostdate, betfrom, checktime, matchid, bettype)
			select @transid_rng, custid, CURRENT_TIMESTAMP, 0, odds, stake, [status], creator, RefNo, winlostdate, betfrom, transdate, ProductID, gameID
			from BettransRNG14 with (nolock)
			where Transid = @transid_rng
        end		

		if ( @statusID in (102,103) and  @isjpgame = 1)
		begin
			update dbo.BettransRNG14 with (rowlock, updlock) -- jp bet ticket
			set 
				[status] = @status,	
				statusID = @statusID,
				Winlost = @WinLost,
				Awinlost = @aWinLost,
				Mwinlost = @mWinLost,
				Swinlost = @sWinLost,
				Playercomm = @PlayerComm,
				Comm = @Comm,
				Acomm = @aComm,
				Scomm = @sComm,
				Transdate3rd = @settleTime3rd,
				refno = @refno,
				winlostdate = @winlostdate,
				ContributionStake3rd = 0			
			where Transid = @transid_rng

			if (@refno2 <> 0)
			begin
				--get ticketinfo from contribution type
				select 	@db_refno_contri = RefNo,@db_BetStake_contri = BetStake, 
				   @db_ContributionStake3rd_contri = ContributionStake3rd,
				   @db_WinLost_contri = winlost, @db_aWinLost_contri = awinlost,
				   @db_mWinLost_contri = mwinlost, @db_sWinLost_contri = swinlost,
				   @db_gameID_contri = gameID,@db_transdesc_contri = transdesc,@db_isSum_contri = isSum
				from dbo.BettransRNG14 with (nolock) where Transid = @refno2

				exec Dot_Intg_SummaryRefNo_Retrieve_Void14_tmp
					@custId = @custid,
					@betTypeId = @db_gameID_contri, --data from contribution ticket
					@winloseDate = @winlostdate,
					@sportTypeId = @productID,
					@actualRate = @actualRate,
					@virtualRate = @virtualRate,
					@recommend = @recommend,
					@mrecommend = @mrecommend,
					@srecommend = @srecommend,
					@betFrom = @betFrom,
					@currency = @currency,
					@currencyName = @currencyName,
					@ip = @ip,
					@transdesc = @db_transdesc_contri, --data from contribution ticket
					@userName = @username,
					@refNo = @refno_refund_contri OUTPUT--get new RefNo if cross-day settled(for refund contribution ticket)
			
				update dbo.BettransRNG14 with (rowlock, updlock) -- contribution ticket
				set 
					[status] = @status,	
					statusID = @statusID,
					Winlost = 0,
					Awinlost = @aWinLost,
					Mwinlost = @mWinLost,
					Swinlost = @sWinLost,
					Playercomm = @PlayerComm,
					Comm = @Comm,
					Acomm = @aComm,
					Scomm = @sComm,
					Transdate3rd = @settleTime3rd,				
					winlostdate = @winlostdate,
					BetStake = 0,
					ContributionStake3rd = 0,
					refno = @refno_refund_contri			
				where Transid = @refno2
			end
		end else
		begin

			update dbo.BettransRNG14 with (rowlock, updlock)
			set 
				[status] = @status,	
				statusID = @statusID,
				Winlost = @WinLost,
				Awinlost = @aWinLost,
				Mwinlost = @mWinLost,
				Swinlost = @sWinLost,
				Playercomm = @PlayerComm,
				Comm = @Comm,
				Acomm = @aComm,
				Scomm = @sComm,
				Transdate3rd = @settleTime3rd,
				refno = @refno,
				winlostdate = @winlostdate,
				JackpotInfo = case when @jackpotwin > 0 then 'jp=1,jpw=' + CONVERT(varchar, @transid_jpwin) else @db_JackpotInfo end			
			where Transid = @transid_rng
		end

		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement        ---
		---------------------------VVVV------------------------------
        select @BalanceAfter = (winlost - actual_stake + playercomm)
		from dbo.BettransRNG14 with (rowlock)
		where Transid = @transid_rng

		if (@isSum = 1)
		begin
			--Un-summarize : take BettransRNG14 from old (winlostdate) bettrans
			update bettrans14 with (rowlock, updlock)
			set
				stake -= @db_stake,
				actual_stake -= @db_actual_stake,
				winlost  -= @db_WinLost,
				awinlost -= @db_aWinLost,
				mwinlost -= @db_mWinLost,
				swinlost -= @db_sWinLost,
				playercomm -= @db_PlayerComm,
				comm	   -= @db_Comm,
				acomm	   -= @db_aComm,
				scomm	   -= @db_sComm,
				[status] = case when ((bt.winlost - @db_WinLost) - (bt.actual_stake - @db_actual_stake)) > 0 then 'WON'
								when ((bt.winlost - @db_WinLost) - (bt.actual_stake - @db_actual_stake)) = 0 then 'DRAW'
								else 'LOSE' end,
				statusID = case when ((bt.winlost - @db_WinLost) - (bt.actual_stake - @db_actual_stake)) > 0 then 112
								when ((bt.winlost - @db_WinLost) - (bt.actual_stake - @db_actual_stake)) = 0 then 111
								else 113 end,
				oddsspread -= @db_BetStake,
				betid -= @db_ContributionStake3rd * 100000000
			from bettrans14 bt
			where bt.transid = @db_refno

			--prepare for Re-summarize winlost
			update BettransRNG14 with (rowlock, updlock) 
			set isSum = 0
			where Transid = @transid_rng and RefNo = @refNo
			
			declare @TVP_SummarizeRNG [TVP_SummarizeRNG] 
			insert into @TVP_SummarizeRNG (transid, refNo)
			select @transid_rng ,@refNo

			--Re-summarize : add BettransRNG14 into new (winlostdate) bettrans
			declare @ErrCode_ByRefNo int = -1, @ErrMsg_ByRefNo nvarchar(200) = ''
			exec Dot_Intg_Summarize_VendorRNG_ByRefNo_Void14_tmp @TVP_SummarizeRNG=@TVP_SummarizeRNG, @ErrCode_ByRefNo=@ErrCode_ByRefNo output, @ErrMsg_ByRefNo=@ErrMsg_ByRefNo output

			if ((@statusID = 102 or @statusID = 103) and @refno2 > 0 and @db_isSum_contri = 1)
			begin
				-- contribution ticket
				update bettrans14 with (rowlock, updlock)
				set
					oddsspread -= @db_BetStake_contri,
					betid -= @db_ContributionStake3rd_contri * 100000000,
					winlost -= @db_WinLost_contri,
					awinlost -= @db_aWinLost_contri,
					mwinlost -= @db_mWinLost_contri,
					swinlost -= @db_sWinLost_contri
				from bettrans14 bt
				where bt.transid = @db_refno_contri

				--prepare for Re-summarize winlost for contribution
				update BettransRNG14 with (rowlock, updlock) 

				set isSum = 0
				where Transid = @refno2 and RefNo = @refno_refund_contri
			
				declare @TVP_SummarizeRNG_Contribution [TVP_SummarizeRNG] 
				insert into @TVP_SummarizeRNG_Contribution (transid, refNo)
				select @refno2 ,@refno_refund_contri

				--Re-summarize : add BettransRNG14 into new (winlostdate) bettrans
				declare @ErrCode_ByRefNo_Contribution int = -1, @ErrMsg_ByRefNo_Contribution nvarchar(200) = ''
				exec Dot_Intg_Summarize_VendorRNG_ByRefNo_Void14_tmp @TVP_SummarizeRNG=@TVP_SummarizeRNG_Contribution, @ErrCode_ByRefNo=@ErrCode_ByRefNo_Contribution output, @ErrMsg_ByRefNo=@ErrMsg_ByRefNo_Contribution output
			end
		end

		
		declare @BalanceList as TVP_BalanceList, @Type as tinyint
		--type : 1=Sports/2=Transfer/3=Casino/4=Others
		select @Type = dbo.f_GetBalanceType(@gameID)
		insert @BalanceList (custID, balance) values (@custid, abs(@BalanceAfter-@BalanceBefore))

		-------------------------------------------------------------
		---                   compare BALANCE                     ---
		---------------------------VVVV------------------------------
        if @BalanceBefore > @BalanceAfter  
		begin
			exec dbo.Dot_BalancePendingDebitIns @BalanceList, @Type, @ErrCode
        end

 		if @BalanceBefore < @BalanceAfter
		begin
			exec dbo.Dot_BalancePendingCreditIns @BalanceList, @Type, @ErrCode
        end

		-------------------------------------------------------------
		---                   compare WinLimit                    ---
		---------------------------VVVV------------------------------
		declare @betTypeRefId smallint, @gameTypeId smallint
		exec Intg_GetWinLimitBetTypes @gameID, @betTypeRefId=@betTypeRefId output, @gameTypeId=@gameTypeId output
		
		if @WinLost < @stake
		begin
			insert into dbo.BalancePendingDebitGame (custid ,winlostdate, balance, bettype, GameTypeID)
			values (@custid, @winlostdate, abs(@WinLost - @db_actual_stake), @betTypeRefId, @gameTypeId)
		end

		if @WinLost > @stake
		begin
			insert into dbo.BalancePendingCreditGame (custid, winlostdate, balance, bettype, GameTypeID)
			values (@custid, @winlostdate, abs(@WinLost - @db_actual_stake), @betTypeRefId, @gameTypeId)
		end
	end

    select @refno as transid, @transid_rng as transid_rng, @winlostdate as eventdate, @username as Username, @transdate as transdate, @db_Status as BFStatus, @status as AFStatus, @transdesc as transdesc, @ErrCode_ByRefNo as ErrCode_ByRefNo, @ErrMsg_ByRefNo as ErrMsg_ByRefNo
END

GO
