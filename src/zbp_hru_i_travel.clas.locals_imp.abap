CLASS lsc_ZI_TRAVAL_TECH_U DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS adjust_numbers REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_TRAVAL_TECH_U IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD adjust_numbers.
    DATA: lt_travel_mapping       TYPE /dmo/if_flight_legacy=>tt_ln_travel_mapping,
          lt_booking_mapping      TYPE /dmo/if_flight_legacy=>tt_ln_booking_mapping,
          lt_bookingsuppl_mapping TYPE /dmo/if_flight_legacy=>tt_ln_bookingsuppl_mapping.

    CALL FUNCTION '/DMO/FLIGHT_TRAVEL_ADJ_NUMBERS'
      IMPORTING
        et_travel_mapping       = lt_travel_mapping
        et_booking_mapping      = lt_booking_mapping
        et_bookingsuppl_mapping = lt_bookingsuppl_mapping.


    mapped-travel =  VALUE #( FOR ls_travel IN lt_travel_mapping ( %tmp = VALUE #( TravelID =  ls_travel-preliminary-travel_id )
                                                                   TravelID = ls_travel-final-travel_id    ) ).


    mapped-booking =  VALUE #( FOR ls_booking IN lt_booking_mapping ( %tmp = VALUE #( TravelID =  ls_booking-preliminary-travel_id
                                                                                       BookingID = ls_booking-preliminary-booking_id )
                                                                      TravelID = ls_booking-final-travel_id
                                                                      BookingID = ls_booking-final-booking_id   ) ).

  ENDMETHOD.

  METHOD save.

    CALL FUNCTION '/DMO/FLIGHT_TRAVEL_SAVE'.

  ENDMETHOD.

  METHOD cleanup.
    CALL FUNCTION '/DMO/FLIGHT_TRAVEL_INITIALIZE'.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
