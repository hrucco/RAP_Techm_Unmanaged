@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Travel'

define root view entity ZHRU_I_TRAVEL
  as select from /dmo/travel as Travel -- the travel table is the data source for this view

  composition [0..*] of ZHRU_I_BOOKING       as _Booking

  association [0..1] to /DMO/I_Agency           as _Agency       on $projection.AgencyID = _Agency.AgencyID
  association [0..1] to /DMO/I_Customer         as _Customer     on $projection.CustomerID = _Customer.CustomerID
  association [0..1] to I_Currency              as _Currency     on $projection.CurrencyCode = _Currency.Currency
  association [1..1] to /DMO/I_Travel_Status_VH as _TravelStatus on $projection.Status = _TravelStatus.TravelStatus

{
  key Travel.travel_id     as TravelID,

      Travel.agency_id     as AgencyID,

      Travel.customer_id   as CustomerID,

      Travel.begin_date    as BeginDate,

      Travel.end_date      as EndDate,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Travel.booking_fee   as BookingFee,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Travel.total_price   as TotalPrice,

      Travel.currency_code as CurrencyCode,

      Travel.description   as Memo,

      Travel.status        as Status,

      Travel.lastchangedat as LastChangedAt,

      /* Associations */
      _Booking,
      _Agency,
      _Customer,
      _Currency,
      _TravelStatus
}
