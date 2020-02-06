package org.jboss.test.arquillian.ce.sso.support;

import org.hamcrest.Description;
import org.hamcrest.Matcher;
import org.hamcrest.StringDescription;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.function.Supplier;

import static java.lang.Thread.sleep;

/**
 * @author mhajas
 */
public class WaitUtils {

    public static <T> void waitForCondition(Supplier<T> itemSupplier, Matcher<T> matcher, long timeout, TimeUnit timeUnit) throws TimeoutException, InterruptedException {
        long waitUntil = System.currentTimeMillis() + timeUnit.toMillis(timeout);
        while (!matcher.matches(itemSupplier.get()) && System.currentTimeMillis() <= waitUntil) {
            sleep(250);
        }

        T item = itemSupplier.get();

        if (!matcher.matches(item)) {
            Description description = new StringDescription();
            description.appendText("\nExpected: ").appendDescriptionOf(matcher).appendText("\n     but: ");
            matcher.describeMismatch(item, description);
            throw new TimeoutException("Timeout hit (" + timeout + " " + timeUnit.toString().toLowerCase() + ") while waiting for condition to match. " + description.toString());
        }
    }

}
