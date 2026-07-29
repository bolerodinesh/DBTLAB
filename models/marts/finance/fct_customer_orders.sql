with

    -- Import CTEs
    customers as (select * from {{ source("jaffle_shop", "customers") }}),

    orders as (select * from {{ source("jaffle_shop", "orders") }}),

    payments as (select * from {{ source("stripe", "payment") }}),

    -- Logical CTEs
    payment_success as (
        select
            orderid as order_id,
            max(created) as payment_finalized_date,
            sum(amount) / 100.0 as total_amount_paid
        from payments
        where status <> 'fail'
        group by 1
    ),

    paid_orders as (
        select
            orders.id as order_id,
            orders.user_id as customer_id,
            orders.order_date as order_placed_at,
            orders.status as order_status,
            payment_success.total_amount_paid,
            payment_success.payment_finalized_date,
            customers.first_name as customer_first_name,
            customers.last_name as customer_last_name
        from orders
        left join payment_success on orders.id = payment_success.order_id
        left join customers on orders.user_id = customers.id
    ),

    -- Final CTE
    final as (
        select
            p.*,
            row_number() over (order by p.order_id) as transaction_seq,
            row_number() over (
                partition by customer_id order by p.order_id
            ) as customer_sales_seq,
            case
                when
                    (
                        rank() over (
                            partition by customer_id
                            order by order_placed_at, p.order_id
                        )
                        = 1
                    )
                then 'new'
                else 'return'
            end as nvsr,
            sum(total_amount_paid) over (
                partition by customer_id order by order_placed_at, p.order_id
            ) as customer_lifetime_value,
            first_value(p.order_placed_at) over (
                partition by customer_id order by order_placed_at, p.order_id asc
            ) as fdos
        from paid_orders p
        order by order_id
    )
-- Simple Select Statmen
select *
from final
